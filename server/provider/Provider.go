package provider

import "lyrics/model"

type Provider interface {
	// Lyrics Base64 字符串
	Lyrics(request model.SearchRequest) []model.MusicRelation
}
