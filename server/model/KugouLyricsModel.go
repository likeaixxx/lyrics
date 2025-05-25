package model

type KugouLyricsModel struct {
	Status      int    `json:"status"`
	Info        string `json:"info"`
	ErrorCode   int    `json:"error_code"`
	Fmt         string `json:"fmt"`
	Contenttype int    `json:"contenttype"`
	Source      string `json:"_source"`
	Charset     string `json:"charset"`
	Content     string `json:"content"`
	Id          string `json:"id"`
}
