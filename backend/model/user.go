package model

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/rwcarlsen/goexif/exif"
	"github.com/rwcarlsen/goexif/tiff"
	"github.com/teris-io/shortid"
	"golang.org/x/crypto/bcrypt"
)

var (
	uid *shortid.Shortid
)

func init() {
	sid, err := shortid.New(1, shortid.DefaultABC, 2342)
	if err != nil {
		panic(err)
	}
	uid = sid
}

type ExifData struct {
	Data map[string]*tiff.Tag
}

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
func (u *User) AddMedia(name string, cType string, content []byte) error {
	var (
		exd string
	)
	dtFormat := "2006-01-02T15:04:05.000Z"
	dt := time.Now().UTC().Format(dtFormat)
	if strings.Index(cType, "image/") == 0 {
		// read exif info
		x, err := exif.Decode(bytes.NewReader(content))
		ed := &ExifData{}
		if err == nil {
			if err := x.Walk(ed); err != nil {
				return err
			}
			if len(ed.Data) > 0 {
				ex, err := json.Marshal(ed.Data)
				if err != nil {
					return err
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
		return err
	}
	if err != nil {
		log.Fatal(err)
	}
	ext := filepath.Ext(name)
	log.Printf("Ext: %v", ext)
	p, err := uid.Generate()
	if err != nil {
		return err
	}
	dp := dataPath(u.Name)
	pDir := filepath.Join(dp, dt[0:7])
	os.MkdirAll(pDir, os.ModeDir)
	pFile := filepath.Join(pDir, p+ext)
	if err := ioutil.WriteFile(pFile, content, 0644); err != nil {
		return err
	}
	_, err = db.Exec("insert into media(name, ctype, path, date, size, exif) values(?, ?, ?, ?, ?, ?)",
		name, cType, filepath.Join(dt[0:7], p+ext), dt, len(content), exd)
	return err
}
