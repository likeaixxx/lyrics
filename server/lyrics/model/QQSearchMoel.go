package model

type QQMusicSearch struct {
	Code    int               `json:"code"`
	Data    QQMusicSearchData `json:"data"`
	Subcode int               `json:"subcode"`
}

type QQMusicSearchData struct {
	Album  QQMusicSearchAlbum  `json:"album"`
	Mv     QQMusicSearchMv     `json:"mv"`
	Singer QQMusicSearchSinger `json:"singer"`
	Song   QQMusicSearchSong   `json:"song"`
}

type QQMusicSearchAlbum struct {
	Count    int `json:"count"`
	Itemlist []struct {
		Docid  string `json:"docid"`
		ID     string `json:"id"`
		Mid    string `json:"mid"`
		Name   string `json:"name"`
		Pic    string `json:"pic"`
		Singer string `json:"singer"`
	} `json:"itemlist"`
	Name  string `json:"name"`
	Order int    `json:"order"`
	Type  int    `json:"type"`
}

type QQMusicSearchMv struct {
	Count    int `json:"count"`
	Itemlist []struct {
		Docid  string `json:"docid"`
		ID     string `json:"id"`
		Mid    string `json:"mid"`
		Name   string `json:"name"`
		Singer string `json:"singer"`
		Vid    string `json:"vid"`
	} `json:"itemlist"`
	Name  string `json:"name"`
	Order int    `json:"order"`
	Type  int    `json:"type"`
}

type QQMusicSearchSinger struct {
	Count    int `json:"count"`
	Itemlist []interface {
	} `json:"itemlist"`
	Name  string `json:"name"`
	Order int    `json:"order"`
	Type  int    `json:"type"`
}

type QQMusicSearchSong struct {
	Count    int `json:"count"`
	Itemlist []struct {
		Docid  string `json:"docid"`
		ID     string `json:"id"`
		Mid    string `json:"mid"`
		Name   string `json:"name"`
		Singer string `json:"singer"`
	} `json:"itemlist"`
	Name  string `json:"name"`
	Order int    `json:"order"`
	Type  int    `json:"type"`
}
