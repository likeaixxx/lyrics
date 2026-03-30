package provider

import (
	"bytes"
	"crypto/aes"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/rand"
	"strconv"
	"time"
)

func aesEncryptECB(data, key []byte) []byte {
	block, _ := aes.NewCipher(key)
	blockSize := block.BlockSize()
	padding := blockSize - len(data)%blockSize
	padText := bytes.Repeat([]byte{byte(padding)}, padding)
	data = append(data, padText...)

	encrypted := make([]byte, len(data))
	for bs, be := 0, blockSize; bs < len(data); bs, be = bs+blockSize, be+blockSize {
		block.Encrypt(encrypted[bs:be], data[bs:be])
	}
	return encrypted
}

func md5Hash(text string) string {
	h := md5.New()
	h.Write([]byte(text))
	return hex.EncodeToString(h.Sum(nil))
}

func eApiParam(reqURL string, object map[string]interface{}) string {
	eapiKey := []byte("e82ckenh8dichen8")
	modifiedUrl := bytes.ReplaceAll([]byte(reqURL), []byte("https://interface3.music.163.com/e"), []byte("/"))
	modifiedUrl = bytes.ReplaceAll(modifiedUrl, []byte("https://interface.music.163.com/e"), []byte("/"))

	jsonData, _ := json.Marshal(object)
	text := string(jsonData)

	message := "nobody" + string(modifiedUrl) + "use" + text + "md5forencrypt"
	digest := md5Hash(message)

	dataStr := string(modifiedUrl) + "-36cd479b6b5-" + text + "-36cd479b6b5-" + digest
	encrypted := aesEncryptECB([]byte(dataStr), eapiKey)

	// to upper hex string
	return hex.EncodeToString(encrypted)
}

func buildEAPIHeader() map[string]string {
	rand.Seed(time.Now().UnixNano())
	requestId := strconv.FormatInt(time.Now().UnixNano()/1e6, 10) + "_" + fmt.Sprintf("%04d", rand.Intn(1000))

	return map[string]string{
		"__csrf":      "",
		"appver":      "8.0.0",
		"buildver":    strconv.FormatInt(time.Now().Unix(), 10),
		"channel":     "",
		"deviceId":    "",
		"mobilename":  "",
		"resolution":  "1920x1080",
		"os":          "android",
		"osver":       "",
		"requestId":   requestId,
		"versioncode": "140",
		"MUSIC_U":     "",
	}
}
