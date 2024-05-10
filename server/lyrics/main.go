package main

import (
	"log"
	"lyrics/router"
)

func init() {
	log.SetPrefix("[Lyrics] ")
	// 初始化全局日志对象
	log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
}

func main() {
	router.Run()
}
