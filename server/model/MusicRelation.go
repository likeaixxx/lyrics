package model

type MusicRelation struct {
	Singer string `json:"singer"`
	Name   string `json:"name"`
	Sid    string `json:"sid"`
	Lid    string `json:"lid"`
	Lyrics string `json:"lyrics"`
	Trans  string `json:"trans"`
	Type   string `json:"type"`
	Offset int64  `json:"offset"`
}

type MusicRelationOffset struct {
	Sid    string `json:"sid"`
	Lid    string `json:"lid"`
	Offset int64  `json:"offset"`
}
