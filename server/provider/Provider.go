package provider

import "lyrics/model"

const (
	QQ        = "QQ Music"
	KuGou     = "KuGou Music"
	NetEase   = "NetEase Music"
	LRCLIBType    = "LRCLIB"
	KugouLKType   = "KuGou (LK)"
	NetEaseLKType = "NetEase (LK)"
	QQMusicLKType = "QQ Music (LK)"
)

type Provider interface {
	// Lyrics Base64 字符串
	Lyrics(request model.SearchRequest) []model.MusicRelation
}
