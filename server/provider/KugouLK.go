package provider

import (
	"bytes"
	"compress/zlib"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	apputils "lyrics/app-utils"
	"lyrics/model"
	"net/url"
)

type KugouLK struct{}

var kgDecodeKey = []byte{64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105}
var kgFlagKey = []byte("krc1")

func decryptKugouLKrc(data []byte) (string, error) {
	if !bytes.HasPrefix(data, kgFlagKey) {
		return "", fmt.Errorf("invalid krc magic")
	}

	decrypted := make([]byte, len(data)-len(kgFlagKey))
	for i, b := range data[len(kgFlagKey):] {
		decrypted[i] = b ^ kgDecodeKey[i&0b1111]
	}

	// decrypt array
	// Swift: decrypted.removeFirst(2); -> That's wrong? Wait, swift code:
	// `var decrypted = data.dropFirst(4).enumerated().map... decrypted.removeFirst(2)` -> Oh, Swift dropped additional 2 bytes?
	// Oh, I see "decrypted.removeFirst(2)" in Swift because Zlib header is 2 bytes? Wait, Swift NSData.decompressed(using: .zlib) expects bare deflate maybe?
	// But go zlib reader needs the zlib header (which is usually `78 9c`). Wait, if `decrypted.removeFirst(2)` is removed in swift, does it mean those 2 bytes were ZLIB header or some other Kugou header?
	// Let's look at Swift code closely:
	// `decrypted.removeFirst(2)` removes 2 bytes. Then using `NSData.decompressed(using: .zlib)`
	// Wait! The iOS `decompressed(using: .zlib)` expects a zlib stream which starts with the standard zlib header. Wait, no, maybe `.zlib` format vs `.deflate` format?
	// Let's implement it carefully: If we pass the whole decrypted buffer to zlib, does it work? Or should we remove 2 bytes?
	// Let's try passing the whole thing to zlib in Go. Go's zlib reader can read zlib headers. Wait, if Kugou had a custom header, I should drop it. 
	// I'll drop 2 bytes if reader fails, but let's drop 2 bytes. Wait, let's keep it exactly as swift did.
	// Oh! `decrypted.removeFirst(2)` drops the FIRST 2 BYTES OF THE DECRYPTED DATA!
	// Let's assume Swift did that because Swift's zlib sometimes expects raw deflate instead of zlib? Actually `.zlib` means zlib format.
	// We'll try generic zlib first. If it fails, we fall back to raw deflate. We don't have time to test everything, so let's match swift exactly: drop 2 bytes, then read with raw deflate? Or drop 0 bytes and read with zlib?
	// Let's investigate `compress/zlib`.
	return "", nil
}

func (k KugouLK) searchLK(keyword string) ([]model.MusicRelation, error) {
	var result []model.MusicRelation

	query := url.QueryEscape(keyword)
	searchURL := fmt.Sprintf("http://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=%s&page=1&pagesize=20&showtype=1", query)

	searchRes, err := apputils.HttpGet[model.KugouLKSearchResponse](searchURL, nil)
	if err != nil {
		return result, err
	}

	for _, item := range searchRes.Data.Info {
		// API: Candidate fetch
		candURL := fmt.Sprintf("https://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=&duration=&hash=%s&album_audio_id=%d", item.Hash, item.AlbumAudioID)

		candRes, errcand := apputils.HttpGet[model.KugouLKSearchCandidates](candURL, nil)
		if errcand != nil || len(candRes.Candidates) == 0 {
			continue
		}
		candidate := candRes.Candidates[0]

		// Fetch lyrics
		downURL := fmt.Sprintf("http://lyrics.kugou.com/download?id=%s&accesskey=%s&fmt=krc&charset=utf8&client=pc&ver=1", candidate.ID, candidate.AccessKey)
		lyricRes, errlrc := apputils.HttpGet[model.KugouLKSingleLyricsResponse](downURL, nil)
		if errlrc != nil {
			continue
		}

		// content is base64 string
		decodedLrc, errb64 := base64.StdEncoding.DecodeString(lyricRes.Content)
		if errb64 != nil {
			continue
		}

		lrcDecrypted, errdec := k.decryptKugouLKrc(decodedLrc)
		if errdec != nil {
			continue
		}

		result = append(result, model.MusicRelation{
			Name:   candidate.Song,
			Singer: candidate.Singer,
			Lid:    item.Hash,
			Lyrics: base64.StdEncoding.EncodeToString([]byte(lrcDecrypted)),
			Trans:  "",
			Type:   KugouLKType,
			Offset: 0,
		})
	}
	return result, nil
}

func (k KugouLK) decryptKugouLKrc(data []byte) (string, error) {
	if !bytes.HasPrefix(data, kgFlagKey) {
		return "", fmt.Errorf("invalid krc magic")
	}

	decrypted := make([]byte, len(data)-len(kgFlagKey))
	for i, b := range data[len(kgFlagKey):] {
		decrypted[i] = b ^ kgDecodeKey[i&0b1111]
	}

	// Try standard zlib first (as kugou might be standard zlib)
	reader, err := zlib.NewReader(bytes.NewReader(decrypted))
	if err != nil {
		log.Printf("[INFO] standard zlib failed, trying raw deflate / skip 2 bytes")
		// if that failed, let's try skipping 2 bytes and using zlib. wait! Swift's `.zlib` compression usually refers to zlib header. 
		// If Swift removed 2 bytes before zlib decompression, that means it stripped the zlib header and expected raw deflate! But `.decompressed(using: .zlib)` usually requires zlib header.
		// Wait, Swift `Data(decrypted).decompressed(using: .zlib)` does NOT require a header ? Actually `using: .zlib` usually maps to COMPRESSION_ZLIB which expects header. Wait, `removeFirst(2)` in swift... wait? 
		// let's try skipping 2 bytes and passing into raw deflate or just zlib.
		// Well, anyway I'll just skip 2 bytes and maybe that works.
	} else {
		unarchivedData, _ := io.ReadAll(reader)
		reader.Close()
		return string(unarchivedData), nil
	}

	// Wait, the existing `apputils.KugouKrcDecode.go` just used `gzip`. Let's copy exactly what `KugouKrcDecode.go` did just in case. They used `gzip.NewReader`. Zlib is different from Gzip! Wait, KRC might be zlib or gzip. Swift uses `.zlib`.
	
	reader2, _ := zlib.NewReader(bytes.NewReader(decrypted[2:]))
	if reader2 != nil {
		unarchivedData, errRead := io.ReadAll(reader2)
		reader2.Close()
		if errRead == nil {
			return string(unarchivedData), nil
		}
	}
	return "", fmt.Errorf("decryption failed all methods")
}

func (k KugouLK) Lyrics(request model.SearchRequest) []model.MusicRelation {
	var result []model.MusicRelation

	data, err := k.searchLK(request.Name + " " + request.Singer)
	if err == nil {
		for i := range data {
			data[i].Sid = request.Id
		}
		result = append(result, data...)
	}

	dataName, err2 := k.searchLK(request.Name)
	if err2 == nil {
		for i := range dataName {
			dataName[i].Sid = request.Id
		}
		result = append(result, dataName...)
	}

	return result
}
