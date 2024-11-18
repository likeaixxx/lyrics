package app_utils

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/gin-gonic/gin"
	"io"
	"log"
	"net/http"
)

var C = http.DefaultClient

func FromGinPostJson[T any](c *gin.Context) T {
	var search T
	err := c.ShouldBindBodyWithJSON(&search)
	if err != nil {
		panic(err)
	}
	return search
}

func HttpGet[T any](urlRedirect string, headers map[string]string) (T, error) {
	req, err := http.NewRequest("GET", urlRedirect, nil)
	req.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	var data T
	resp, err := C.Do(req)
	if err != nil {
		return data, err
	}
	if resp.StatusCode != http.StatusOK {
		return data, errors.New(fmt.Sprintf("Search [%s] API Response %d", urlRedirect, resp.StatusCode))
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return data, err
	}
	err = json.Unmarshal(body, &data)
	if err != nil {
		log.Println(err)
		return data, errors.New("Not Format JSON [" + string(body) + "]")
	}
	log.Printf("API [%s] Format Json %s\n", urlRedirect, string(body))
	return data, nil
}

func HttpPost[T any, R any](form R, url string, headers map[string]string) (T, error) {
	var data T
	body, err := json.Marshal(form)
	if err != nil {
		log.Printf(fmt.Sprintf("[ERROR] Not Format JSON %s", err.Error()))
		return data, err
	}

	log.Println(fmt.Sprintf("[INFO] Request Body: %s", string(body)))

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(body))
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.110 Safari/537.36")
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := C.Do(req)
	if err != nil {
		return data, err
	}
	if resp.StatusCode != http.StatusOK {
		return data, errors.New(fmt.Sprintf("Search [%s, %s] API Response %d", url, body, resp.StatusCode))
	}
	responseBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return data, err
	}
	err = json.Unmarshal(responseBody, &data)
	if err != nil {
		return data, errors.New("Not Format JSON [" + string(responseBody) + "]")
	}
	return data, nil
}
