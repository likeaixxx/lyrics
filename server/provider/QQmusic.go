package provider

import (
	"errors"
	"fmt"
	"strings"

	"log"
	"lyrics/app-utils"
	"lyrics/model"
	"net/url"
	"strconv"
)

const QQMusic = "QQ Music"

type QQMusicLyrics struct {
}

var searchBaseUrl = "https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?key=%s"
var lyricsBaseUrl = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=%s&g_tk=5381&format=json"

func (search QQMusicLyrics) Lyrics(request model.SearchRequest) []model.MusicRelation {
	var result []model.MusicRelation

	data, done := search.search(request.Name + "-" + request.Singer)
	if done {
		return result
	}

	if len(data.Data.Song.Itemlist) < 1 {
		data, done = search.search(request.Name)
		if done {
			return result
		}
		if len(data.Data.Song.Itemlist) < 1 {
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

	for _, song := range data.Data.Song.Itemlist {
		log.Printf(fmt.Sprintf("[INFO] GET Song [%s - %s], MusicId [%s]", song.Name, song.Singer, song.Mid))
		lyrics, err := search.lyrics(song.Mid)
		if err != nil {
			log.Printf(err.Error())
			continue
		}
		result = append(result, model.MusicRelation{
			Name:   song.Name,
			Singer: song.Singer,
			Lid:    song.Mid,
			Sid:    request.Id,
			// 获取歌词
			Lyrics: lyrics,
			Type:   QQMusic,
		})
	}
	return result
}

func (search QQMusicLyrics) search(source string) (model.QQMusicSearch, bool) {
	key, err := app_utils.T2s(source)
	log.Printf("[INFO] T2s Res " + key)
	if err != nil {
		log.Printf(fmt.Sprintf("[ERROR] T2s Failed [%s] %v", source, err))
		key = source
	}
	data, err := app_utils.HttpGet[model.QQMusicSearch](fmt.Sprintf(searchBaseUrl, url.QueryEscape(key)), map[string]string{})
	if err != nil {
		log.Printf("[ERROR] Failed GET QQ Music Response!")
		return model.QQMusicSearch{}, true
	}

	if data.Code != 0 {
		log.Printf("Search QQMusic API Error Code " + strconv.Itoa(data.Code) + " Subcode " + strconv.Itoa(data.Subcode))
		return model.QQMusicSearch{}, true
	}
	return data, false
}

func (search QQMusicLyrics) lyrics(mid string) (string, error) {
	headers := map[string]string{"referer": "https://y.qq.com/portal/player.html"}
	data, err := app_utils.HttpGet[model.QQMusicLyrics](fmt.Sprintf(lyricsBaseUrl, mid), headers)
	if err != nil {
		return "", errors.New(fmt.Sprintf("[ERROR] Failed Get QQMusic Lyrics [%s - %s]: %s", mid, lyricsBaseUrl, err))
	}
	if data.Code != 0 {
		return "", errors.New(fmt.Sprintf("[ERROR] Failed to get lyrics for Music [%s - %s]", mid, strconv.Itoa(data.Code)))
	}
	return data.Lyric, nil
}
