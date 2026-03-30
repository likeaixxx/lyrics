package provider

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strconv"
	
	apputils "lyrics/app-utils"
	"lyrics/model"
)

type NetEaseLK struct{}

func (search NetEaseLK) Lyrics(request model.SearchRequest) []model.MusicRelation {
	var result []model.MusicRelation

	data, err := search.searchLK(request.Name + " " + request.Singer)
	if err != nil {
		return result
	}

	if len(data.Result.Songs) < 1 {
		data, _ = search.searchLK(request.Name)
	}

	for _, song := range data.Result.Songs {
		var singer string
		for _, artist := range song.Artists {
			if singer == "" {
				singer = artist.Name
			} else {
				singer += "/" + artist.Name
			}
		}

		lyrics, err := search.lyricsLK(song.ID)
		if err != nil || lyrics == "" {
			continue
		}

		result = append(result, model.MusicRelation{
			Name:   song.Name,
			Singer: singer,
			Lid:    strconv.Itoa(song.ID),
			Sid:    request.Id,
			Lyrics: base64.StdEncoding.EncodeToString([]byte(lyrics)),
			Trans:  "",
			Type:   NetEaseLKType, // Use the new constant
			Offset: 0,
		})
	}
	return result
}

func (search NetEaseLK) searchLK(keyword string) (model.NetEaseLKSearchResponse, error) {
	var response model.NetEaseLKSearchResponse
	key, err := apputils.T2s(keyword)
	if err != nil {
		key = keyword
	}

	params := url.Values{}
	params.Add("offset", "0")
	params.Add("limit", "10")
	params.Add("type", "1")
	params.Add("s", key)
	queryUrl := "http://music.163.com/api/search/pc?" + params.Encode()
	
	req, err := http.NewRequest("POST", queryUrl, nil)
	if err != nil {
		return response, err
	}
	req.Header.Set("Referer", "http://music.163.com/")
	req.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15")

	resp, err := apputils.C.Do(req)
	if err != nil {
		return response, err
	}
	
	cookie := resp.Header.Get("Set-Cookie")
	if cookie != "" {
		// Just send another GET with the cookie? Swift code does exactly that but with the same queryUrl?
		// "The Swift implementation POSTs once, gets Set-Cookie, sets it, then re-GETs or re-POSTs"
		// Actually, in Swift: `req.setValue(cookie, forHTTPHeaderField: "Cookie"); let (data, _) = try await URLSession.shared.data(for: req)`
		req2, _ := http.NewRequest("POST", queryUrl, nil) // or GET? Swift was mutated req
		req2.Header.Set("Referer", "http://music.163.com/")
		req2.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15")
		// parse cookie up to ;
		for i := 0; i < len(cookie); i++ {
			if cookie[i] == ';' {
				cookie = cookie[:i]
				break
			}
		}
		req2.Header.Set("Cookie", cookie)
		resp, err = apputils.C.Do(req2)
		if err != nil {
			return response, err
		}
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	json.Unmarshal(body, &response)

	return response, nil
}

func (search NetEaseLK) lyricsLK(id int) (string, error) {
	lyricsURL := "https://interface3.music.163.com/eapi/song/lyric/v1"
	data := map[string]interface{}{
		"id":         strconv.Itoa(id),
		"cp":         "false",
		"lv":         "0",
		"kv":         "0",
		"tv":         "0",
		"rv":         "0",
		"yv":         "0",
		"ytv":        "0",
		"yrv":        "0",
		"csrf_token": "",
	}

	headerMap := buildEAPIHeader()
	hData, _ := json.Marshal(headerMap)
	data["header"] = string(hData)

	hexParams := eApiParam(lyricsURL, data)

	// Modified URL replacing api with eapi
	reqURL := "https://interface3.music.163.com/eapi/song/lyric/v1"
	
	formData := url.Values{}
	// must be uppercase hex
	formData.Set("params", fmt.Sprintf("%X", []byte(hexParams)) ) 
	// Wait, the eApiParam returns hex string, we can just use strings.ToUpper
	
	formData.Set("params", hexParams)

	req, err := http.NewRequest("POST", reqURL, bytes.NewBufferString(formData.Encode()))
	if err != nil {
		return "", err
	}

	req.Header.Set("User-Agent", "Mozilla/5.0 (Linux; Android 9; PCT-AL10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.64 HuaweiBrowser/10.0.3.311 Mobile Safari/537.36")
	req.Header.Set("Referer", "https://music.163.com/")
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	
	// Set cookies
	cookieStr := ""
	for k, v := range headerMap {
		cookieStr += fmt.Sprintf("%s=%s; ", k, v)
	}
	req.Header.Set("Cookie", cookieStr)

	resp, err := apputils.C.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	
	body, _ := io.ReadAll(resp.Body)
	var singleLyricsResponse model.NetEaseLKSingleLyricsResponse
	json.Unmarshal(body, &singleLyricsResponse)
	
	log.Printf("[INFO] Fetched LK NetEase code: %d", singleLyricsResponse.Code)

	lyr := ""
	if singleLyricsResponse.Yrc.Lyric != "" {
		lyr = singleLyricsResponse.Yrc.Lyric
	} else if singleLyricsResponse.KLyric.Lyric != "" {
		lyr = singleLyricsResponse.KLyric.Lyric
	} else if singleLyricsResponse.Lrc.Lyric != "" {
		lyr = singleLyricsResponse.Lrc.Lyric
	} else {
		return "", fmt.Errorf("no lyric found")
	}

	return lyr, nil
}
