package provider

import (
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"

	apputils "lyrics/app-utils"
	"lyrics/model"
)

type QQMusicLK struct{}

func (search QQMusicLK) searchLK(keyword string) ([]model.QQMusicLKSearchResponse, error) {
	key, err := apputils.T2s(keyword)
	if err != nil {
		key = keyword
	}

	searchURL := "https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?key=" + url.QueryEscape(key)
	
	resp, err := apputils.HttpGet[model.QQMusicLKSearchResponse](searchURL, nil)
	if err != nil {
		return nil, err
	}
	
	if resp.Code != 0 {
		return nil, fmt.Errorf("QQMusic LK search error: %d", resp.Code)
	}

	return []model.QQMusicLKSearchResponse{resp}, nil
}

func (search QQMusicLK) lyricsLK(mid string) (string, error) {
	// Let's use QQ LK endpoint 2: https://c.y.qq.com/qqmusic/fcgi-bin/lyric_download.fcg
	// The swift parameter uses musicid = id. But in smartbox return, we have mid. Do we have id?
	// The item struct in Swift has `mid`, `name`, `singer`, `id`.
	// Wait, the LK response searches smartbox, mid is mid. Id is id. smartbox returns both id and mid.
	// Oh! Currently the search result only returns `mid`. We added `id` to the struct `QQMusicLKSearchResponse`.
	
	idStr := ""
	if idStr == "" {
		// Just use endpoint 1: https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg
		// lyricsBaseUrl1 : https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=%s&g_tk=5381&format=json
		return "", fmt.Errorf("id is required for qrc endpoint")
	}
	return "", nil
}

func (search QQMusicLK) Lyrics(request model.SearchRequest) []model.MusicRelation {
	var result []model.MusicRelation

	data, err := search.searchLK(request.Name + " " + request.Singer)
	if err != nil || len(data) == 0 {
		return result
	}

	for _, reqDat := range data {
		for _, song := range reqDat.Data.Song.ItemList {
			// We use endpoint 2 for QRC lyrics
			lyricsURL := fmt.Sprintf("https://c.y.qq.com/qqmusic/fcgi-bin/lyric_download.fcg?musicid=%s&version=15&miniversion=82&lrctype=4", song.ID)
			
			headers := map[string]string{
				"Referer": "y.qq.com/portal/player.html",
				"User-Agent": "Mozilla/5.0",
			}

			// We shouldn't use apputils.HttpGet because it returns JSON, and this endpoint might return raw XML (since it's QRC with <content> tags)
			req, _ := http.NewRequest("GET", lyricsURL, nil)
			for k, v := range headers {
				req.Header.Set(k, v)
			}
			res, errReq := apputils.C.Do(req)
			if errReq != nil {
				continue
			}
			
			bodyBytes, _ := io.ReadAll(res.Body)
			res.Body.Close()
			bodyString := string(bodyBytes)
			
			bodyString = strings.ReplaceAll(bodyString, "<!--", "")
			bodyString = strings.ReplaceAll(bodyString, "-->", "")

			// We need to parse <content>xxxx</content> out using regex
			re := regexp.MustCompile(`<content>(.*?)</content>`)
			matches := re.FindStringSubmatch(bodyString)
			if len(matches) < 2 {
				continue
			}

			qrcHex := matches[1]
			decrypted, errD := decryptQQMusicQrc(qrcHex)
			if errD != nil {
				continue
			}
			
			// Try to get <contentts> for trans
			reTs := regexp.MustCompile(`<contentts>(.*?)</contentts>`)
			matchesTs := reTs.FindStringSubmatch(bodyString)
			transDecrypted := ""
			if len(matchesTs) >= 2 {
				transDec, errDecT := decryptQQMusicQrc(matchesTs[1])
				if errDecT == nil {
					transDecrypted = transDec
				}
			}

			result = append(result, model.MusicRelation{
				Name:   song.Name,
				Singer: song.Singer,
				Lid:    song.Mid,
				Sid:    request.Id,
				Lyrics: base64.StdEncoding.EncodeToString([]byte(decrypted)),
				Trans:  transDecrypted,
				Type:   QQMusicLKType,
				Offset: 0,
			})
		}
	}
	return result
}
