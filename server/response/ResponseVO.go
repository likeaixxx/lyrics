package response

import (
	"github.com/gin-gonic/gin"
	"net/http"
)

type VO struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data"`
}

func Success(c *gin.Context) {
	c.JSON(http.StatusOK, VO{Code: 0, Message: "success"})
}

func Ok(data any, c *gin.Context) {
	c.JSON(http.StatusOK, VO{Code: 0, Message: "success", Data: data})
}

func Failed(message string, c *gin.Context) {
	Error(http.StatusInternalServerError, message, nil, c)
}

func Ret(code int, message string, c *gin.Context) {
	Error(code, message, nil, c)
}

func Error(code int, message string, data any, c *gin.Context) {
	c.JSON(code, VO{Code: code, Message: message, Data: data})
}
