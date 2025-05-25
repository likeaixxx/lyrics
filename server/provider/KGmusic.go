package provider

import (
	"errors"
	"fmt"
	app_utils "lyrics/app-utils"
	"net/url"
	"strconv"
	"strings"

	"log"
	"lyrics/model"
)

type KugouMusic struct {
}

var kugouSearch = "http://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=%s&page=1&pagesize=10&showtype=1"
var kugouMusicDetail = "http://krcs.kugou.com/search?ver=1&man=yes&client=mobi&hash=%s"
var kugouLyricsBaseUrl = "http://lyrics.kugou.com/download?ver=1&client=pc&id=%s&accesskey=%s&fmt=krc&charset=utf8"

func (search KugouMusic) Lyrics(request model.SearchRequest) []model.MusicRelation {
	var result []model.MusicRelation

	data, done := search.search(request.Name + " " + request.Singer)
	if done {
		return result
	}

	if len(data.Data.Info) < 1 {
		data, done = search.search(request.Name)
		if done {
			return result
		}
		if len(data.Data.Info) < 1 {
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

	for _, info := range data.Data.Info {
		log.Printf(fmt.Sprintf("[INFO] GET Song [%s - %s], MusicId [%s, %s]", info.Songname, info.Singername, info.Hash, request.Id))
		detail, err := search.detail(info.Hash)
		if err != nil {
			log.Println(err)
			continue
		}
		for _, song := range detail.Candidates {
			lyrics, err := search.lyrics(song.Id, song.Accesskey)
			if err != nil {
				log.Println(fmt.Sprintf("[ERROR] search lyrics [%s,%s,%s,%s]", song.Id, song.Accesskey, song.Song, info.Hash), err)
				continue
			}
			result = append(result, model.MusicRelation{
				Name:   song.Song,
				Singer: song.Singer,
				Lid:    fmt.Sprintf("%s-%s-%s", info.Hash, song.Id, song.Accesskey),
				Sid:    request.Id,
				// 获取歌词
				Lyrics: lyrics,
				Type:   KuGou,
				Offset: 0,
			})
		}

	}
	return result
}

func (search KugouMusic) search(source string) (model.KugouSearchModel, bool) {
	key, err := app_utils.T2s(source)
	log.Printf("[INFO] T2s Res " + key)
	if err != nil {
		log.Printf(fmt.Sprintf("[ERROR] T2s Failed [%s] %v", source, err))
		key = source
	}
	data, err := app_utils.HttpGet[model.KugouSearchModel](fmt.Sprintf(kugouSearch, url.QueryEscape(key)), map[string]string{})
	if err != nil {
		log.Printf("[ERROR] Failed GET Kugou Music Response!")
		return model.KugouSearchModel{}, true
	}

	if data.Errcode != 0 {
		log.Printf("Search Kugou API Error Code " + strconv.Itoa(data.Status) + " Subcode " + data.Error)
		return model.KugouSearchModel{}, true
	}
	return data, false
}

func (search KugouMusic) detail(hash string) (model.KugouDetailModel, error) {
	var detail model.KugouDetailModel
	detail, err := app_utils.HttpGet[model.KugouDetailModel](fmt.Sprintf(kugouMusicDetail, hash), map[string]string{})
	if err != nil {
		return detail, errors.New(fmt.Sprintf("[ERROR] Failed Get Kugou Detail [%s - %s]: %s", hash, lyricsBaseUrl, err))
	}
	if detail.Status != 200 {
		return detail, errors.New(fmt.Sprintf("[ERROR] Failed to get Kugou Detail for Music [%s - %s]", hash, detail.Errmsg))
	}
	return detail, nil
}

func (search KugouMusic) lyrics(id string, accesskey string) (string, error) {
	lyrics, err := app_utils.HttpGet[model.KugouLyricsModel](fmt.Sprintf(kugouLyricsBaseUrl, id, accesskey), map[string]string{})
	if err != nil {
		return lyrics.Content, errors.New(fmt.Sprintf("[ERROR] Failed Get Kugou Lyrics [%s-%s - %s]: %s", id, accesskey, lyricsBaseUrl, err))
	}
	if lyrics.Status != 200 {
		return lyrics.Content, errors.New(fmt.Sprintf("[ERROR] Failed to get Kugou lyrics for Music [%s-%s - %s]", id, accesskey, lyrics.Content))
	}
	log.Printf("[INFO] KuGou Decode by %s", lyrics.Fmt)
	return lyrics.Content, nil
}
