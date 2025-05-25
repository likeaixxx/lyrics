package provider

import (
	"encoding/base64"
	"errors"
	"fmt"
	"log"
	apputils "lyrics/app-utils"
	"lyrics/model"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

var netEaseMusicSearch = "http://music.163.com/api/search/pc"
var netEaseLyrics = "https://music.163.com/api/song/media?id=%d"

type NetEaseMusic struct{}

func (search NetEaseMusic) Lyrics(request model.SearchRequest) []model.MusicRelation {
	var result []model.MusicRelation

	data, done := search.search(request.Name + " " + request.Singer)
	if done {
		return result
	}

	if len(data.Result.Songs) < 1 {
		data, done = search.search(request.Name)
		if done {
			return result
		}
		if len(data.Result.Songs) < 1 {
			// log.Printf("Not Get song info [%s]", )
			split := []string{"(", "（", "-", "《"}
			minIndex := len(request.Name)
			for _, sep := range split {
				if idx := strings.Index(request.Name, sep); idx != -1 && idx < minIndex {
					minIndex = idx
				}
			}
			if minIndex == len(request.Name) {
				return result
			}
			data, done = search.search(request.Name[:minIndex])
		}
	}
	for _, song := range data.Result.Songs {
		var singer string
		for _, artist := range song.Artists {
			singer = fmt.Sprintf("%s/%s", singer, artist.Name)
		}
		singer = strings.Replace(singer, "/", "", len(singer)-1)
		log.Printf(fmt.Sprintf("[INFO] GET Song [%s - %s], MusicId [%d, %s]", song.Name, singer, song.Id, request.Id))

		lyrics, err := search.lyrics(song.Id)
		if err != nil {
			log.Printf(err.Error())
			continue
		}
		if lyrics == "" {
			continue
		}
		encoding := base64.StdEncoding
		result = append(result, model.MusicRelation{
			Name:   song.Name,
			Singer: singer,
			Lid:    strconv.Itoa(song.Id),
			Sid:    request.Id,
			// 获取歌词
			Lyrics: encoding.EncodeToString([]byte(lyrics)),
			Trans:  "",
			Type:   NetEase,
			Offset: 0,
		})
	}
	return result
}

func (search NetEaseMusic) search(key string) (model.NetEaseSearchResponse, bool) {
	key, err := apputils.T2s(key)
	params := url.Values{}
	params.Add("offset", "0")
	params.Add("limit", "10")
	params.Add("type", "1")
	params.Add("s", key)
	queryUrl := netEaseMusicSearch + "?" + params.Encode()
	log.Printf("[INFO] NETEASE escape URL %s", queryUrl)

	headers := map[string]string{
		"sec-ch-ua":                 "\"Chromium\";v=\"131\", \"Not_A Brand\";v=\"24\"",
		"sec-ch-ua-mobile":          "?0",
		"sec-ch-ua-platform":        "\"macOS\"",
		"sec-fetch-dest":            "document",
		"sec-fetch-mode":            "navigate",
		"sec-fetch-user":            "?1",
		"upgrade-insecure-requests": "1",
		"priority":                  "u=0, i",
		"dnt":                       "1",
		"accept-language":           "zh-CN,zh;q=0.9",
		"cache-control":             "max-age=0",
		"Referer":                   "http://music.163.com/",
		// ":scheme":                   "https",
		// ":authority": "music.163.com",
		"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15",
		// "Cookie":     cookie[:strings.Index(cookie, ";")],
	}

	var response model.NetEaseSearchResponse
	req, err := http.NewRequest("GET", queryUrl, nil)
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := apputils.C.Do(req)
	if err != nil {
		log.Printf("[ERROR] GET Cookie Failed NetEase Music Search Error: %s", err.Error())
		return response, true
	}
	// resp, err := http.Get(url)
	// if err != nil {
	// 	log.Printf("[ERROR] GET Cookie Failed NetEase Music Search Error: %s", err.Error())
	// 	return response, true
	// }
	cookie := resp.Header.Get("Set-Cookie")
	if len(cookie) < 1 {
		log.Printf("[ERROR] GET Cookie Failed NetEase Music Search Error")
		return response, true
	}
	log.Printf("[INFO] cookies %v", cookie[:strings.Index(cookie, ";")])
	headers["Cookie"] = cookie[:strings.Index(cookie, ";")]
	response, err = apputils.HttpGet[model.NetEaseSearchResponse](queryUrl, headers)
	if err != nil {
		log.Printf("[ERROR] Failed Get NetEase Music [%s - %s]: %s", key, queryUrl, err)
		return response, true
	}
	if response.Code != 200 {
		log.Printf("[ERROR] Failed Get NetEase Music [%s - %s]: %d", key, queryUrl, response.Code)
		return response, true
	}

	return response, false
}

func (search NetEaseMusic) lyrics(id int) (string, error) {
	response, err := apputils.HttpGet[model.NetEaseLyricsResponse](fmt.Sprintf(netEaseLyrics, id), map[string]string{})
	if err != nil {
		return "", errors.New(fmt.Sprintf("[ERROR] Failed Get NetEase Lyrics [%d - %s]: %s", id, lyricsBaseUrl, err))
	}
	if response.Code != 200 {
		return "", errors.New(fmt.Sprintf("[ERROR] Failed to get NetEase lyrics for Music [%d - %s]", id, strconv.Itoa(response.Code)))
	}
	return response.Lyric, nil
}
