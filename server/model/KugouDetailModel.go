package model

type KugouDetailModel struct {
	Status           int    `json:"status"`
	Info             string `json:"info"`
	Errcode          int    `json:"errcode"`
	Errmsg           string `json:"errmsg"`
	Keyword          string `json:"keyword"`
	Proposal         string `json:"proposal"`
	HasCompleteRight int    `json:"has_complete_right"`
	Companys         string `json:"companys"`
	Ugc              int    `json:"ugc"`
	Ugccount         int    `json:"ugccount"`
	Expire           int    `json:"expire"`
	Candidates       []struct {
		Id          string          `json:"id"`
		ProductFrom string          `json:"product_from"`
		Accesskey   string          `json:"accesskey"`
		CanScore    bool            `json:"can_score"`
		Singer      string          `json:"singer"`
		Song        string          `json:"song"`
		Duration    int             `json:"duration"`
		Uid         string          `json:"uid"`
		Nickname    string          `json:"nickname"`
		Origiuid    string          `json:"origiuid"`
		Transuid    string          `json:"transuid"`
		Sounduid    string          `json:"sounduid"`
		Originame   string          `json:"originame"`
		Transname   string          `json:"transname"`
		Soundname   string          `json:"soundname"`
		Parinfo     [][]interface{} `json:"parinfo"`
		ParinfoExt  []struct {
			Entry string `json:"entry"`
		} `json:"parinfoExt"`
		Language      string `json:"language"`
		Krctype       int    `json:"krctype"`
		Hitlayer      int    `json:"hitlayer"`
		Hitcasemask   int    `json:"hitcasemask"`
		Adjust        int    `json:"adjust"`
		Score         int    `json:"score"`
		Contenttype   int    `json:"contenttype"`
		ContentFormat int    `json:"content_format"`
	} `json:"candidates"`
	Ugccandidates []interface{} `json:"ugccandidates"`
	Artists       []struct {
		Identity int `json:"identity"`
		Base     struct {
			AuthorId   int    `json:"author_id"`
			AuthorName string `json:"author_name"`
			IsPublish  int    `json:"is_publish"`
			Avatar     string `json:"avatar"`
			Identity   int    `json:"identity"`
			Type       int    `json:"type"`
			Country    string `json:"country"`
			Birthday   string `json:"birthday"`
			Language   string `json:"language"`
		} `json:"base"`
	} `json:"artists"`
	AiCandidates []interface{} `json:"ai_candidates"`
}
