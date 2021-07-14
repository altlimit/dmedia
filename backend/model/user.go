package model

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path"
	"path/filepath"
	"strings"
	"time"

	"github.com/rwcarlsen/goexif/exif"
	"github.com/rwcarlsen/goexif/tiff"
	"github.com/teris-io/shortid"
	"golang.org/x/crypto/bcrypt"
)

var (
	uid      *shortid.Shortid
	dtFormat = "2006-01-02T15:04:05.000Z"
)

func init() {
	sid, err := shortid.New(1, shortid.DefaultABC, 2342)
	if err != nil {
		panic(err)
	}
	uid = sid
}

type (
	Media struct {
		ID          int64                  `json:"id"`
		Name        string                 `json:"name"`
		ContentType string                 `json:"ctype"`
		Path        string                 `json:"path"`
		Date        time.Time              `json:"date"`
		Size        int                    `json:"size"`
		Exif        map[string]interface{} `json:"exif"`
		Meta        map[string]interface{} `json:"meta"`
	}
	ExifData struct {
		Data map[string]*tiff.Tag
	}
)

func (ed *ExifData) Walk(name exif.FieldName, tag *tiff.Tag) error {
	if ed.Data == nil {
		ed.Data = make(map[string]*tiff.Tag)
	}
	ed.Data[string(name)] = tag
	return nil
}

// SetPassword hashes password field with bcrypt
func (u *User) SetPassword(password string) error {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 13)
	if err != nil {
		return err
	}
	u.Password = string(bytes)
	return nil
}

// ValidPassword checks password if correct
func (u *User) ValidPassword(password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(password))
	return err == nil
}

// Save saves user to db
func (u *User) Save() error {
	return saveUser(u)
}

// AddMedia adds new media to table
func (u *User) AddMedia(name string, cType string, content []byte) (int64, error) {
	var (
		exd string
	)
	dt := time.Now().UTC().Format(dtFormat)
	if strings.Index(cType, "image/") == 0 {
		// read exif info
		x, err := exif.Decode(bytes.NewReader(content))
		ed := &ExifData{}
		if err == nil {
			if err := x.Walk(ed); err != nil {
				return 0, err
			}
			if len(ed.Data) > 0 {
				ex, err := json.Marshal(ed.Data)
				if err != nil {
					return 0, err
				}
				exd = string(ex)
				// find possible date
				for k, v := range ed.Data {
					if strings.Contains(k, "DateTime") {
						dts, err := v.StringVal()
						if err == nil {
							t, err := time.Parse("2006:01:02 15:04:05", dts)
							if err == nil {
								dt = t.Format(dtFormat)
								break
							}
						}
					}
				}
			}
		}
	}
	db, err := getDB(u.Name)
	if err != nil {
		return 0, err
	}
	if err != nil {
		log.Fatal(err)
	}
	ext := filepath.Ext(name)
	p, err := uid.Generate()
	if err != nil {
		return 0, err
	}
	dp := dataPath(u.Name)
	pDir := filepath.Join(dp, dt[0:7])
	os.MkdirAll(pDir, os.ModeDir)
	pFile := filepath.Join(pDir, p+ext)
	if err := ioutil.WriteFile(pFile, content, 0644); err != nil {
		return 0, err
	}
	res, err := db.Exec("insert into media(name, ctype, path, date, size, exif) values(?, ?, ?, ?, ?, ?)",
		name, cType, path.Join(dt[0:7], p+ext), dt, len(content), exd)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (u *User) GetAllMedia(page int, limit int) ([]*Media, int, error) {
	db, err := getDB(u.Name)
	if err != nil {
		return nil, 0, err
	}
	row, err := db.Query(fmt.Sprintf(`
		SELECT id, name, ctype, path, date, size, exif, meta 
		FROM media 
		ORDER BY date DESC
		LIMIT %d
		OFFSET %d
	`, limit, (limit*page)-limit))
	if err != nil {
		return nil, 0, err
	}
	defer row.Close()
	var result []*Media
	for row.Next() {
		m, err := getRowMedia(row)
		if err != nil {
			return nil, 0, err
		}
		result = append(result, m)
	}
	r := db.QueryRow(`SELECT COUNT(1) FROM media`)
	var total int
	if err := r.Scan(&total); err != nil {
		return nil, 0, err
	}
	return result, total, nil
}

func (u *User) GetMediaByID(id int) (*Media, error) {
	db, err := getDB(u.Name)
	if err != nil {
		return nil, err
	}
	row, err := db.Query(`
		SELECT id, name, ctype, path, date, size, exif, meta 
		FROM media 
		WHERE id = ?
		LIMIT 1
	`, id)
	if err != nil {
		return nil, err
	}
	defer row.Close()
	for row.Next() {
		m, err := getRowMedia(row)
		if err != nil {
			return nil, err
		}
		return m, nil
	}
	return nil, ErrNotFound
}

func getRowMedia(row *sql.Rows) (*Media, error) {
	m := &Media{Exif: make(map[string]interface{}), Meta: make(map[string]interface{})}
	var date string
	var exif sql.NullString
	var meta sql.NullString
	if err := row.Scan(&m.ID, &m.Name, &m.ContentType, &m.Path, &date, &m.Size, &exif, &meta); err != nil {
		return nil, err
	}
	dt, err := time.Parse(dtFormat, date)
	if err != nil {
		return nil, err
	}
	m.Date = dt
	if exif.Valid && len(exif.String) > 0 {
		log.Println("Exif: ", exif.String)
		if err := json.Unmarshal([]byte(exif.String), &m.Exif); err != nil {
			return nil, err
		}
	}
	if meta.Valid && len(meta.String) > 0 {
		if err := json.Unmarshal([]byte(meta.String), &m.Meta); err != nil {
			return nil, err
		}
	}
	return m, nil
}
