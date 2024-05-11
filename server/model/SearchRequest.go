package model

type SearchRequest struct {
	// 歌名
	Name string `json:"name"`
	// 艺人
	Singer string `json:"singer"`
	// spotify 歌曲ID
	Id string `json:"id"`
	// 强制刷新
	Refresh bool `json:"refresh"`
}
