package router

import (
	"fmt"
	"github.com/gin-gonic/gin"
	"log"
	apputils "lyrics/app-utils"
	"lyrics/model"
	"lyrics/provider"
	"lyrics/response"
)

func Run() {
	r := gin.Default()
	r.Use(ErrorHolder())
	group := r.Group("/api/v1")
	group.POST("/lyrics", lyrics)
	group.POST("/lyrics/confirm", confirm)

	_ = r.Run()
}

func confirm(c *gin.Context) {
	provider.Persist.Upsert(apputils.FromGinPostJson[model.MusicRelation](c))
	response.Success(c)
}

func lyrics(c *gin.Context) {
	request := apputils.FromGinPostJson[model.SearchRequest](c)
	var data []model.MusicRelation
	if request.Refresh != true {
		data = provider.Persist.Lyrics(request)
	}
	if len(data) < 1 {
		data = provider.QQMusicLyrics{}.Lyrics(request)
		log.Printf("len(data) < %d", len(data))
		if len(data) > 0 {
			log.Printf("len(data) > %d", len(data))
			// 随机持久化一条, 后续用户点击后再更新
			provider.Persist.Upsert(data[0])
		}
	}
	response.Ok(data, c)
}

func ErrorHolder() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				response.Failed(fmt.Sprintf("%v", err), c)
			}
		}()
		c.Next()
	}
}
