package model

// LRCLIB
type LRCLIBResponse struct {
	ID           int     `json:"id"`
	Name         string  `json:"name"`
	TrackName    string  `json:"trackName"`
	ArtistName   string  `json:"artistName"`
	AlbumName    string  `json:"albumName"`
	Duration     float64 `json:"duration"`
	Instrumental bool    `json:"instrumental"`
	PlainLyrics  string  `json:"plainLyrics"`
	SyncedLyrics string  `json:"syncedLyrics"`
}

// Kugou
type KugouLKSearchResponse struct {
	Status  int    `json:"status"`
	ErrCode int    `json:"errcode"`
	Error   string `json:"error"`
	Data    struct {
		Info []struct {
			Hash         string `json:"hash"`
			AlbumID      string `json:"album_id"`
			AlbumAudioID int    `json:"album_audio_id"`
		} `json:"info"`
	} `json:"data"`
}

type KugouLKSingleLyricsResponse struct {
	Content string `json:"content"`
	Fmt     string `json:"fmt"`
	Info    string `json:"info"`
	Status  int    `json:"status"`
	Charset string `json:"charset"`
}

type KugouLKSearchCandidates struct {
	Candidates []struct {
		ID        string `json:"id"`
		AccessKey string `json:"accesskey"`
		Song      string `json:"song"`
		Singer    string `json:"singer"`
		Duration  int    `json:"duration"`
	} `json:"candidates"`
}

// NetEase
type NetEaseLKSearchResponse struct {
	Code   int `json:"code"`
	Result struct {
		Songs []struct {
			ID       int    `json:"id"`
			Name     string `json:"name"`
			Duration int    `json:"duration"`
			Album    struct {
				ID     int    `json:"id"`
				Name   string `json:"name"`
				PicURL string `json:"picUrl"`
			} `json:"album"`
			Artists []struct {
				ID   int    `json:"id"`
				Name string `json:"name"`
			} `json:"artists"`
		} `json:"songs"`
		SongCount int `json:"songCount"`
	} `json:"result"`
}

type NetEaseLKSingleLyricsResponse struct {
	Lrc struct {
		Lyric string `json:"lyric"`
	} `json:"lrc"`
	KLyric struct {
		Lyric string `json:"lyric"`
	} `json:"klyric"`
	TLyric struct {
		Lyric string `json:"lyric"`
	} `json:"tlyric"`
	Yrc struct {
		Lyric string `json:"lyric"`
	} `json:"yrc"`
	LyricUser struct {
		Nickname string `json:"nickname"`
	} `json:"lyricUser"`
	Code int `json:"code"`
}

// QQMusic
type QQMusicLKSearchResponse struct {
	Code int `json:"code"`
	Data struct {
		Song struct {
			ItemList []struct {
				Mid    string `json:"mid"`
				Name   string `json:"name"`
				Singer string `json:"singer"`
				ID     string `json:"id"`
			} `json:"itemlist"`
		} `json:"song"`
	} `json:"data"`
}

type QQMusicLKSingleLyricsResponse struct {
	RetCode int    `json:"retcode"`
	Code    int    `json:"code"`
	SubCode int    `json:"subcode"`
	Lyric   string `json:"lyric"`
	Trans   string `json:"trans"`
}
