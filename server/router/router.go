package router

import (
	"fmt"
	"github.com/gin-gonic/gin"
	apputils "lyrics/app-utils"
	"lyrics/model"
	"lyrics/provider"
	"lyrics/response"
	"sync"
)

func Run() {
	r := gin.Default()
	r.Use(ErrorHolder())
	group := r.Group("/api/v1")
	group.POST("/lyrics", lyrics)
	group.POST("/lyrics/confirm", confirm)
	group.POST("/lyrics/offset", offset)

	_ = r.Run("0.0.0.0:8331")
}

func confirm(c *gin.Context) {
	provider.Persist.Upsert(apputils.FromGinPostJson[model.MusicRelation](c))
	response.Success(c)
}

func offset(c *gin.Context) {
	provider.Persist.Offset(apputils.FromGinPostJson[model.MusicRelationOffset](c))
	response.Success(c)
}

// 俺也不知道网易云音乐抽什么风 provider.NetEaseMusic{}
var search = []provider.Provider{provider.QQMusicLyrics{}}

func lyrics(c *gin.Context) {
	request := apputils.FromGinPostJson[model.SearchRequest](c)
	var data []model.MusicRelation
	if request.Refresh != true {
		data = provider.Persist.Lyrics(request)
	}
	if len(data) < 1 {
		cd := make(chan []model.MusicRelation, 1)
		var wg sync.WaitGroup
		for _, p := range search {
			wg.Add(1)
			go func(p provider.Provider) {
				defer wg.Done()
				cd <- p.Lyrics(request)
			}(p)
		}

		go func() {
			wg.Wait()
			close(cd)
		}()

		for d := range cd {
			data = append(data, d...)
		}
		if len(data) > 0 {
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
