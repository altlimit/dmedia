package model

import (
	"bytes"
	"crypto/sha1"
	"database/sql"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/altlimit/dmedia/util"
	"github.com/rwcarlsen/goexif/exif"
	"github.com/rwcarlsen/goexif/tiff"
	"golang.org/x/crypto/bcrypt"
)

const (
	mediaFields = `
		id, name, public, checksum, ctype, path, 
		strftime('%Y-%m-%d', created) as created, strftime('%Y-%m-%d %H:%M:%S', modified) as modified, 
		size, meta`
	userFields = `
		id, name, password, admin, active
	`
)

var (
	dateFormat      = "2006-01-02"
	dateTimeFormat  = "2006-01-02 15:04:05"
	sDateTimeFormat = "2006-01-02T15:04:05.000Z"
	sBool           = map[bool]int{true: 1, false: 0}
)

type (
	User struct {
		ID       int64  `json:"id"`
		Name     string `json:"username" validate:"required,username"`
		Password string `json:"password,omitempty"`
		IsAdmin  bool   `json:"admin"`
		Active   bool   `json:"active"`
	}

	Media struct {
		ID          int64     `json:"id"`
		Name        string    `json:"name"`
		Public      bool      `json:"public"`
		Checksum    string    `json:"checksum"`
		ContentType string    `json:"ctype"`
		Path        string    `json:"path"`
		Created     time.Time `json:"created"`
		Modified    time.Time `json:"modified"`
		Size        int       `json:"size"`
		Meta        *Meta     `json:"meta"`
	}

	Meta struct {
		Exif interface{} `json:"exif,omitempty"`
		Info interface{} `json:"info,omitempty"`
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
		exd     string
		isVideo bool
		meta    *Meta
	)
	created := time.Now().UTC().Format(dateFormat)
	if strings.Index(cType, "image/") == 0 {
		// read exif info
		x, err := exif.Decode(bytes.NewReader(content))
		ed := &ExifData{}
		if err == nil {
			if err := x.Walk(ed); err != nil {
				return 0, err
			}
			if len(ed.Data) > 0 {
				meta = &Meta{Exif: ed.Data}
				// find possible date
				for k, v := range ed.Data {
					if strings.Contains(k, "DateTime") {
						dts, err := v.StringVal()
						if err == nil {
							t, err := time.Parse("2006:01:02 15:04:05", dts)
							if err == nil {
								created = t.Format(dateFormat)
								break
							}
						}
					}
				}
			}
		}
	} else if strings.Index(cType, "video/") == 0 {
		isVideo = true
	} else {
		return 0, ErrNotSupported
	}
	db, err := getDB(u.ID)
	if err != nil {
		return 0, err
	}
	if err != nil {
		log.Fatal(err)
	}
	dp := dataPath(u.ID)
	tmpDir := filepath.Join(dp, "tmp", util.NewID())
	if err := os.MkdirAll(tmpDir, os.ModeDir); err != nil {
		return 0, err
	}
	pFile := filepath.Join(tmpDir, name)
	if err := ioutil.WriteFile(pFile, content, 0644); err != nil {
		return 0, err
	}
	cleanUp := func() {
		if err := os.RemoveAll(tmpDir); err != nil {
			log.Printf("Failed to delete tmpDir: %s - %v", tmpDir, err)
		}
	}
	defer cleanUp()
	if isVideo {
		if info := util.VideoInfo(pFile); info != nil {
			meta = &Meta{Info: info}
		}
	}
	if meta != nil {
		ex, err := json.Marshal(meta)
		if err != nil {
			return 0, err
		}
		exd = string(ex)
	}
	chk := fmt.Sprintf("%x", sha1.Sum(content))
	res, err := db.Exec(`
		insert into media(name, ctype, checksum, created, size, meta, modified) 
		values(?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
		name, cType, chk, created, len(content), exd)
	if err != nil {
		if err := os.Remove(pFile); err != nil {
			return 0, err
		}
		if err.Error() == "UNIQUE constraint failed: media.checksum" {
			r := db.QueryRow(`SELECT id FROM media WHERE checksum = ?`, chk)
			var id int64
			if err := r.Scan(&id); err != nil {
				return 0, err
			}
			return id, nil
		}
		return 0, err
	}
	id, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}
	pDir := filepath.Join(dp, created, util.I64toa(id))
	if err := os.MkdirAll(pDir, os.ModeDir); err != nil {
		return 0, err
	}
	if err := os.Rename(pFile, filepath.Join(pDir, name)); err != nil {
		_, err = db.Exec(`DELETE FROM media WHERE id = ?`, id)
		if err != nil {
			return 0, err
		}
		return 0, err
	}
	return id, nil
}

func (u *User) GetAllMedia(page int, limit int) ([]*Media, int, error) {
	db, err := getDB(u.ID)
	if err != nil {
		return nil, 0, err
	}
	row, err := db.Query(fmt.Sprintf(`
		SELECT %s
		FROM media 
		ORDER BY id DESC
		LIMIT %d
		OFFSET %d
	`, mediaFields, limit, (limit*page)-limit))
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
	db, err := getDB(u.ID)
	if err != nil {
		return nil, err
	}
	row, err := db.Query(fmt.Sprintf(`
		SELECT %s
		FROM media 
		WHERE id = ?
		LIMIT 1
	`, mediaFields), id)
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
	m := &Media{Meta: &Meta{}}
	var (
		created  string
		modified string
		meta     sql.NullString
		public   int
	)
	if err := row.Scan(&m.ID, &m.Name, &public, &m.Checksum, &m.ContentType, &m.Path, &created, &modified, &m.Size, &meta); err != nil {
		return nil, err
	}
	dt, err := time.Parse(dateFormat, created)
	if err != nil {
		return nil, err
	}
	m.Created = dt
	dt, err = time.Parse(dateTimeFormat, modified)
	if err != nil {
		return nil, err
	}
	m.Modified = dt
	m.Public = public == 1
	if meta.Valid && len(meta.String) > 0 {
		if err := json.Unmarshal([]byte(meta.String), m.Meta); err != nil {
			return nil, err
		}
	}
	return m, nil
}

func getRowUser(row *sql.Rows) (*User, error) {
	u := &User{}
	var (
		admin  int
		active int
	)
	if err := row.Scan(&u.ID, &u.Name, &u.Password, &admin, &active); err != nil {
		return nil, err
	}
	u.IsAdmin = admin == 1
	u.Active = active == 1
	return u, nil
}

func GetUsers() ([]*User, error) {
	db, err := getDB(0)
	if err != nil {
		return nil, err
	}
	row, err := db.Query(fmt.Sprintf(`SELECT %s
	FROM user`, userFields))
	defer row.Close()
	var result []*User
	for row.Next() {
		u, err := getRowUser(row)
		if err != nil {
			return nil, err
		}
		result = append(result, u)
	}
	return result, nil
}

func GetUser(userID int64, name string) (*User, error) {
	db, err := getDB(0)
	if err != nil {
		return nil, err
	}
	field := "id"
	var val interface{}
	if name != "" && userID == 0 {
		field = "name"
		val = name
	} else {
		val = userID
	}
	row, err := db.Query(fmt.Sprintf(`SELECT %s
	FROM user
	WHERE %s = ?
	LIMIT 1`, userFields, field), val)
	defer row.Close()
	if err != nil {
		return nil, err
	}
	for row.Next() {
		u, err := getRowUser(row)
		if err != nil {
			return nil, err
		}
		return u, nil
	}
	return nil, ErrNotFound
}

func saveUser(user *User) error {
	db, err := getDB(0)
	if err != nil {
		return err
	}
	args := []interface{}{user.Name, user.Password, sBool[user.IsAdmin], sBool[user.Active]}
	if user.ID == 0 {
		res, err := db.Exec(`
		insert into user(name, password, admin, active) 
		values(?, ?, ?, ?)`, args...)
		if err != nil {
			return err
		}
		id, err := res.LastInsertId()
		if err == nil {
			user.ID = id
		}
	} else {
		args = append(args, user.ID)
		_, err = db.Exec(`
		UPDATE user SET 
		name = ?,
		password = ?,
		admin = ?,
		active = ?
		WHERE id = ?
		`, args...)
	}
	return err
}
