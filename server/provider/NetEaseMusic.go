package provider

import (
	"encoding/base64"
	"errors"
	"fmt"
	"log"
	apputils "lyrics/app-utils"
	"lyrics/model"
	"net/url"
	"strconv"
	"strings"
)

var netEaseMusicSearch = "http://music.163.com/api/search/get/web?csrf_token=hlpretag=&hlposttag=&type=1&offset=0&total=true&limit=20&s="
var netEaseLyrics = "http://music.163.com/api/song/media?id=%d"

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
		encoding := base64.StdEncoding
		result = append(result, model.MusicRelation{
			Name:   song.Name,
			Singer: singer,
			Lid:    strconv.FormatInt(song.Id, 10),
			Sid:    request.Id,
			// 获取歌词
			Lyrics: encoding.EncodeToString([]byte(lyrics)),
			Type:   NetEase,
		})
	}
	return result
}

func (search NetEaseMusic) search(key string) (model.NetEaseSearchResponse, bool) {
	key, err := apputils.T2s(key)
	log.Printf("[INFO] T2s Res " + key)
	header := map[string]string{"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.139 Safari/537.36"}
	log.Printf("[INFO] request endpoint %s", netEaseMusicSearch+url.QueryEscape(key))
	response, err := apputils.HttpGet[model.NetEaseSearchResponse](netEaseMusicSearch+url.QueryEscape(key), header)
	if err != nil {
		log.Printf(fmt.Sprintf("[ERROR] Failed Get NetEase Music [%s - %s]: %s", key, netEaseMusicSearch, err))
		return response, true
	}
	if response.Code != 200 {
		log.Printf(fmt.Sprintf("[ERROR] Failed Get NetEase Music [%s - %s]: %d", key, netEaseMusicSearch, response.Code))
		return response, true
	}

	return response, false
}

func (search NetEaseMusic) lyrics(id int64) (string, error) {
	response, err := apputils.HttpGet[model.NetEaseLyricsResponse](fmt.Sprintf(netEaseLyrics, id), map[string]string{})
	if err != nil {
		return "", errors.New(fmt.Sprintf("[ERROR] Failed Get NetEase Lyrics [%d - %s]: %s", id, lyricsBaseUrl, err))
	}
	if response.Code != 200 {
		return "", errors.New(fmt.Sprintf("[ERROR] Failed to get NetEase lyrics for Music [%d - %s]", id, strconv.Itoa(response.Code)))
	}
	return response.Lyric, nil
}
