package provider

import (
	"database/sql"
	"fmt"
	_ "github.com/mattn/go-sqlite3"
	"log"
	"lyrics/model"
	"os"
)

var path = "./lyrics.db"

type sqlitePersist struct {
	path string
}

var Persist = persistProvider()

func persistProvider() sqlitePersist {
	persist := sqlitePersist{
		path: path,
	}
	return persist.lyricsTable()
}

func (persist sqlitePersist) Lyrics(request model.SearchRequest) []model.MusicRelation {
	var result []model.MusicRelation

	db, err := sql.Open("sqlite3", persist.path)
	if err != nil {
		log.Fatal(err)
	}
	defer func(db *sql.DB) {
		_ = db.Close()
	}(db)

	search := `
      select relation_id, name, singer, lyrics_content, lyrics_trans, lyrics_type, offset from lyrics_relation where spotify_id = ?
	`

	row, err := db.Query(search, request.Id)
	if err != nil {
		log.Printf(fmt.Sprintf("[ERROR] Failed Get Persist %s", err))
		return result
	}

	for row.Next() {
		var mid string
		var name string
		var singer string
		var lyrics string
		var trans string
		var lyricsType string
		var offset int64
		err := row.Scan(&mid, &name, &singer, &lyrics, &trans, &lyricsType, &offset)
		if err != nil {
			log.Printf("[ERROR] Failed Scan Row %s", err)
			continue
		}
		result = append(result, model.MusicRelation{
			Name:   name,
			Singer: singer,
			Lid:    mid,
			Sid:    request.Id,
			// 获取歌词
			Lyrics: lyrics,
			Trans:  trans,
			Type:   lyricsType,
			Offset: offset,
		})
	}
	return result
}

func (persist sqlitePersist) Upsert(result model.MusicRelation) {
	db, err := sql.Open("sqlite3", persist.path)
	if err != nil {
		log.Fatal(err)
	}
	defer func(db *sql.DB) {
		_ = db.Close()
	}(db)

	insert := `
		INSERT OR REPLACE INTO lyrics_relation 
		    (spotify_id, relation_id, name, singer, lyrics_content, lyrics_trans, lyrics_type)
		VALUES 
			(?, ?, ?, ?, ?, ?, ?)
	`

	_, err = db.Exec(insert, result.Sid, result.Lid, result.Name, result.Singer, result.Lyrics, result.Trans, result.Type)
	if err != nil {
		log.Printf(fmt.Sprintf("[ERROR] Failed Insert/Update %s", err))
	}
}

func (persist sqlitePersist) Offset(offset model.MusicRelationOffset) {
	db, err := sql.Open("sqlite3", persist.path)
	if err != nil {
		log.Fatal(err)
	}
	defer func(db *sql.DB) {
		_ = db.Close()
	}(db)
	updateOffset := `update lyrics_relation set offset = ? where spotify_id = ? and relation_id = ?`
	_, err = db.Exec(updateOffset, offset.Offset, offset.Sid, offset.Lid)
	panic(err)
}

// 不管有没有用都先初始化表结构
func (persist sqlitePersist) lyricsTable() sqlitePersist {
	// 检查数据库文件是否存在
	_, err := os.Stat(persist.path)
	if os.IsNotExist(err) {
		// 如果文件不存在，创建一个空的数据库文件
		file, err := os.Create(persist.path)
		if err != nil {
			log.Fatal(err)
		}
		_ = file.Close()
		log.Println("数据库文件已创建:", persist.path)
	}

	db, err := sql.Open("sqlite3", persist.path)
	if err != nil {
		log.Fatal(err)
	}
	defer func(db *sql.DB) {
		_ = db.Close()
	}(db)

	lyricsDB := `
			-- auto-generated definition
			create table lyrics_relation
			(
				spotify_id     TEXT primary key,
				relation_id    TEXT,
				name           text,
				singer         text,
				lyrics_content TEXT,
				lyrics_trans   TEXT,
				lyrics_type    TEXT,
				offset integer default 0,
				created_at     TIMESTAMP default CURRENT_TIMESTAMP
			);
	`
	_, err = db.Exec(lyricsDB)
	if err != nil {
		log.Fatal(err)
	}
	return persist
}
