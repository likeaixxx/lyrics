package model

type NetEaseLyricsResponse struct {
	SongStatus   int    `json:"songStatus"`
	LyricVersion int    `json:"lyricVersion"`
	Lyric        string `json:"lyric"`
	Code         int    `json:"code"`
}

type NetEaseSearchResponse struct {
	Result struct {
		Songs []struct {
			Name    string `json:"name"`
			Id      int    `json:"id"`
			Artists []struct {
				Name string `json:"name"`
				Id   int    `json:"id"`
			} `json:"artists"`
		} `json:"songs"`
		SongCount int `json:"songCount"`
	} `json:"result"`
	Code int `json:"code"`
}
