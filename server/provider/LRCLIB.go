package provider

import (
	"encoding/base64"
	"fmt"
	"log"
	apputils "lyrics/app-utils"
	"lyrics/model"
	"net/url"
)

type LRCLIB struct{}

func (l LRCLIB) Lyrics(request model.SearchRequest) []model.MusicRelation {
	var result []model.MusicRelation

	query := request.Name + " " + request.Singer
	searchURL := fmt.Sprintf("https://lrclib.net/api/search?q=%s", url.QueryEscape(query))

	responses, err := apputils.HttpGet[[]model.LRCLIBResponse](searchURL, nil)
	if err != nil {
		log.Printf("[ERROR] Failed to query LRCLIB: %v", err)
		return result
	}

	for _, item := range responses {
		lyrics := item.SyncedLyrics
		if lyrics == "" {
			lyrics = item.PlainLyrics
		}
		if lyrics == "" {
			continue
		}

		result = append(result, model.MusicRelation{
			Name:   item.TrackName,
			Singer: item.ArtistName,
			Lid:    fmt.Sprintf("%d", item.ID),
			Sid:    request.Id,
			Lyrics: base64.StdEncoding.EncodeToString([]byte(lyrics)),
			Trans:  "",
			Type:   LRCLIBType,
			Offset: 0,
		})
	}

	return result
}
