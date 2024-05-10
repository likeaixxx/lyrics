package model

type QQMusicLyrics struct {
	Retcode int    `json:"retcode"`
	Code    int    `json:"code"`
	Subcode int    `json:"subcode"`
	Lyric   string `json:"lyric"`
	Trans   string `json:"trans"`
}
