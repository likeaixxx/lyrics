package provider

import (
	"bytes"
	"compress/zlib"
	"crypto/des"
	"encoding/hex"
	"io"
)

var qqKey1 = []byte("!@#)(NHLiuy*$%^&")[:8]
var qqKey2 = []byte("123ZXC!@#)(*$%^&")[:8]
var qqKey3 = []byte("!@#)(*$%^&abcDEF")[:8]

func swapDesBytes(b []byte) {
	// bytes 0..3 reversed
	b[0], b[1], b[2], b[3] = b[3], b[2], b[1], b[0]
	// bytes 4..7 reversed
	b[4], b[5], b[6], b[7] = b[7], b[6], b[5], b[4]
}

func decryptQQMusicQrc(hexStr string) (string, error) {
	data, err := hex.DecodeString(hexStr)
	if err != nil {
		return "", err
	}

	key1 := make([]byte, 8)
	key2 := make([]byte, 8)
	key3 := make([]byte, 8)
	copy(key1, qqKey1)
	copy(key2, qqKey2)
	copy(key3, qqKey3)

	swapDesBytes(key1)
	swapDesBytes(key2)
	swapDesBytes(key3)

	var key3des []byte
	key3des = append(key3des, key1...)
	key3des = append(key3des, key2...)
	key3des = append(key3des, key3...)

	blk, err := des.NewTripleDESCipher(key3des)
	if err != nil {
		return "", err
	}

	for i := 0; i+8 <= len(data); i += 8 {
		block := data[i : i+8]
		swapDesBytes(block)
		blk.Decrypt(block, block)
		swapDesBytes(block)
	}

	if len(data) < 2 {
		return "", nil
	}

	// Drop first 2 bytes before zlib decompress as in LyricsKit swift code
	// Swift `byteData.removeFirst(2)` + `decompressed(using: .zlib)`
	reader, err := zlib.NewReader(bytes.NewReader(data[2:]))
	if err != nil {
		// try without dropping 2 bytes if standard zlib
		reader2, err2 := zlib.NewReader(bytes.NewReader(data))
		if err2 != nil {
			return "", err2
		}
		defer reader2.Close()
		decompressed, _ := io.ReadAll(reader2)
		return string(decompressed), nil
	}
	defer reader.Close()

	decompressed, err := io.ReadAll(reader)
	if err != nil {
		return "", err
	}

	return string(decompressed), nil
}
