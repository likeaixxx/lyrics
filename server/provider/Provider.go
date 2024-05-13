package provider

import "lyrics/model"

const (
	QQ      = "QQ Music"
	KuGou   = "KuGou Music"
	NetEase = "NetEase Music"
)

type Provider interface {
	// Lyrics Base64 字符串
	Lyrics(request model.SearchRequest) []model.MusicRelation
}
