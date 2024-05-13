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
			Id      int64  `json:"id"`
			Name    string `json:"name"`
			Artists []struct {
				Id        int           `json:"id"`
				Name      string        `json:"name"`
				PicUrl    interface{}   `json:"picUrl"`
				Alias     []interface{} `json:"alias"`
				AlbumSize int           `json:"albumSize"`
				PicId     int           `json:"picId"`
				FansGroup interface{}   `json:"fansGroup"`
				Img1V1Url string        `json:"img1v1Url"`
				Img1V1    int           `json:"img1v1"`
				Trans     interface{}   `json:"trans"`
			} `json:"artists"`
			Album struct {
				Id     int    `json:"id"`
				Name   string `json:"name"`
				Artist struct {
					Id        int           `json:"id"`
					Name      string        `json:"name"`
					PicUrl    interface{}   `json:"picUrl"`
					Alias     []interface{} `json:"alias"`
					AlbumSize int           `json:"albumSize"`
					PicId     int           `json:"picId"`
					FansGroup interface{}   `json:"fansGroup"`
					Img1V1Url string        `json:"img1v1Url"`
					Img1V1    int           `json:"img1v1"`
					Trans     interface{}   `json:"trans"`
				} `json:"artist"`
				PublishTime int64 `json:"publishTime"`
				Size        int   `json:"size"`
				CopyrightId int   `json:"copyrightId"`
				Status      int   `json:"status"`
				PicId       int64 `json:"picId"`
				Mark        int   `json:"mark"`
			} `json:"album"`
			Duration    int           `json:"duration"`
			CopyrightId int           `json:"copyrightId"`
			Status      int           `json:"status"`
			Alias       []interface{} `json:"alias"`
			Rtype       int           `json:"rtype"`
			Ftype       int           `json:"ftype"`
			Mvid        int           `json:"mvid"`
			Fee         int           `json:"fee"`
			RUrl        interface{}   `json:"rUrl"`
			Mark        int64         `json:"mark"`
		} `json:"songs"`
		SongCount int `json:"songCount"`
	} `json:"result"`
	Code int `json:"code"`
}
