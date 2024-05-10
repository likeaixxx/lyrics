package model

type Result struct {
	Singer string `json:"singer"`
	Name   string `json:"name"`
	Sid    string `json:"sid"`
	Lid    string `json:"lid"`
	Lyrics string `json:"lyrics"`
	Type   string `json:"type"`
}
