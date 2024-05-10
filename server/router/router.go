package router

import (
	"fmt"
	"github.com/gin-gonic/gin"
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

	_ = r.Run()
}

func lyrics(c *gin.Context) {
	data := provider.QQMusicLyrics{}.Lyrics(apputils.FromGinPostJson[model.SearchRequest](c))
	// log.Printf("%v", data)
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
