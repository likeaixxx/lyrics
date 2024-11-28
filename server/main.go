package main

import (
	"log"
)

func init() {
	log.SetPrefix("[Lyrics] ")
	// 初始化全局日志对象
	log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
}

func main() {
	Run()
}
