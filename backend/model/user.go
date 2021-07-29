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
	"sync"
	"time"

	"github.com/altlimit/dmedia/util"
	"github.com/rwcarlsen/goexif/exif"
	"github.com/rwcarlsen/goexif/tiff"
	"golang.org/x/crypto/bcrypt"
)

const (
	mediaFields = `
		id, name, public, checksum, ctype,
		strftime('%Y-%m-%d %H:%M:%S', created) as created, strftime('%Y-%m-%d %H:%M:%S', modified) as modified, 
		size, meta, strftime('%Y-%m-%d %H:%M:%S', deleted) as deleted`
	userFields = `
		id, name, password, admin, active
	`
)

var (
	sBool = map[bool]int{true: 1, false: 0}
)

type (
	DateTime time.Time
	User     struct {
		ID       int64  `json:"id"`
		Name     string `json:"username" validate:"required"`
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
		Created     DateTime  `json:"created"`
		Modified    DateTime  `json:"modified"`
		Deleted     *DateTime `json:"deleted"`
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

func (t DateTime) MarshalJSON() ([]byte, error) {
	stamp := fmt.Sprintf("\"%s\"", time.Time(t).Format(util.DateTimeFormat))
	return []byte(stamp), nil
}

func (ed *ExifData) Walk(name exif.FieldName, tag *tiff.Tag) error {
	if ed.Data == nil {
		ed.Data = make(map[string]*tiff.Tag)
	}
	ed.Data[string(name)] = tag
	return nil
}

func (m *Media) Path(userID int64) string {
	created := time.Time(m.Created)
	return filepath.Join(util.DataPath, util.I64toa(userID), created.Format(util.DateFormat), util.I64toa(m.ID), m.Name)
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

// AddMediaFromPath adds new media from local path
func (u *User) AddMediaFromPath(path string) (int64, error) {
	name := filepath.Base(path)
	cType := util.TypeByExt(filepath.Ext(name))
	content, err := ioutil.ReadFile(path)
	if err != nil {
		return 0, err
	}
	fbDate := util.TimeFromPath(path)
	return u.AddMedia(name, cType, content, fbDate.Format(util.DateTimeFormat))
}

// AddMedia adds new media to table
func (u *User) AddMedia(name string, cType string, content []byte, fallbackDT string) (int64, error) {
	var (
		exd         string
		isVideo     bool
		meta        *Meta
		createdTime time.Time
		err         error
	)
	if len(content) == 0 {
		return 0, fmt.Errorf("AddMedia: error content is empty")
	}
	if fallbackDT != "" {
		createdTime, err = time.Parse(util.DateTimeFormat, fallbackDT)
		if err != nil {
			return 0, fmt.Errorf("AddMedia: error time.Parse %v", err)
		}
	} else {
		createdTime = util.TimeFromPath(name)
	}
	created := createdTime.Format(util.DateTimeFormat)
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
								created = t.Format(util.DateTimeFormat)
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
		log.Printf("Found ContentType: %s", cType)
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
	if err := os.MkdirAll(tmpDir, 0755); err != nil {
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
	pDir := filepath.Join(dp, created[0:10], util.I64toa(id))
	if err := os.MkdirAll(pDir, 0755); err != nil {
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

func (u *User) GetAllMedia(deleted bool, page int, limit int) ([]*Media, int, error) {
	db, err := getDB(u.ID)
	if err != nil {
		return nil, 0, fmt.Errorf("GetAllMedia getDB error: %v", err)
	}
	var (
		where string
		args  []interface{}
	)
	if deleted {
		where = "WHERE deleted IS NOT NULL"
	} else {
		where = "WHERE deleted IS NULL"
	}
	row, err := db.Query(fmt.Sprintf(`
		SELECT %s
		FROM media
		%s
		ORDER BY created DESC
		LIMIT %d
		OFFSET %d
	`, mediaFields, where, limit, (limit*page)-limit), args...)
	if err != nil {
		return nil, 0, fmt.Errorf("GetAllMedia db.Query error: %v", err)
	}
	defer row.Close()
	var result []*Media
	for row.Next() {
		m, err := getRowMedia(row)
		if err != nil {
			return nil, 0, fmt.Errorf("GetAllMedia getRowMedia error: %v", err)
		}
		result = append(result, m)
	}
	r := db.QueryRow(`SELECT COUNT(1) FROM media`)
	var total int
	if err := r.Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("GetAllMedia db.QueryRow error: %v", err)
	}
	return result, total, nil
}

func (u *User) GetMediaByID(id int64) (*Media, error) {
	db, err := getDB(u.ID)
	if err != nil {
		return nil, fmt.Errorf("GetMediaByID getDB error: %v", err)
	}
	row, err := db.Query(fmt.Sprintf(`
		SELECT %s
		FROM media 
		WHERE id = ?
		LIMIT 1
	`, mediaFields), id)
	if err != nil {
		return nil, fmt.Errorf("GetMediaByID db.Query error: %v", err)
	}
	defer row.Close()
	for row.Next() {
		m, err := getRowMedia(row)
		if err != nil {
			return nil, fmt.Errorf("GetMediaByID getRowMedia error: %v", err)
		}
		return m, nil
	}
	return nil, ErrNotFound
}

func (u *User) DeleteMediaById(ids []int64) error {
	db, err := getDB(u.ID)
	if err != nil {
		return fmt.Errorf("DeleteMediaById getDB error: %v", err)
	}
	cleanIDs := strings.Join(util.Int64ToStrings(ids), ",")
	var (
		delIDs        []int64
		pathsToDelete []string
	)
	row, err := db.Query(fmt.Sprintf(`
		SELECT %s
		FROM media
		WHERE id IN (%s)
	`, mediaFields, cleanIDs))
	if err != nil {
		return fmt.Errorf("DeleteMediaById db.Query error: %v", err)
	}
	defer row.Close()
	rowCtr := 0
	for row.Next() {
		m, err := getRowMedia(row)
		if err != nil {
			return fmt.Errorf("DeleteMediaById getRowMedia error: %v", err)
		}
		if m.Deleted != nil {
			// permanent
			delIDs = append(delIDs, m.ID)
			pathsToDelete = append(pathsToDelete, m.Path(u.ID))
		}
		rowCtr++
	}
	if rowCtr == 0 {
		return ErrNotFound
	}

	if len(delIDs) > 0 {
		res, err := db.Exec(fmt.Sprintf(`DELETE FROM media
		WHERE id IN (%s)`, strings.Join(util.Int64ToStrings(delIDs), ",")))
		if err != nil {
			return fmt.Errorf("DeleteMediaById db.Exec 2 error %v", err)
		}
		affected, err := res.RowsAffected()
		if err != nil {
			return fmt.Errorf("DeleteMediaById RowsAffected error %v", err)
		}
		delFiles := len(pathsToDelete)
		if int(affected) != delFiles {
			log.Printf("[WARNING] DeleteMediaById permanent deletion ids didn't match paths: %v -> %v", affected, pathsToDelete)
		}
		var wg sync.WaitGroup
		wg.Add(delFiles)
		for i := 0; i < delFiles; i++ {
			go func(p string) {
				defer wg.Done()
				dir := filepath.Dir(p)
				if err := os.RemoveAll(dir); err != nil {
					log.Printf("[ERROR] os.RemoveAll(%s) -> %v", dir, err)
				}
			}(pathsToDelete[i])
		}
		wg.Wait()
	}

	_, err = db.Exec(fmt.Sprintf(`
		UPDATE media
		SET 
			modified=CURRENT_TIMESTAMP,
			deleted=CURRENT_TIMESTAMP
		WHERE id IN (%s);
	`, cleanIDs))
	if err != nil {
		return fmt.Errorf("DeleteMediaById db.Query error: %v", err)
	}
	return nil
}

func getRowMedia(row *sql.Rows) (*Media, error) {
	m := &Media{Meta: &Meta{}}
	var (
		created  string
		modified string
		deleted  sql.NullString
		meta     sql.NullString
		public   int
	)
	if err := row.Scan(&m.ID, &m.Name, &public, &m.Checksum, &m.ContentType, &created, &modified, &m.Size, &meta, &deleted); err != nil {
		return nil, fmt.Errorf("getRowMedia row.Scan error: %v", err)
	}
	dt, err := time.Parse(util.DateTimeFormat, created)
	if err != nil {
		return nil, fmt.Errorf("getRowMedia time.Parse error: %v", err)
	}
	m.Created = DateTime(dt)
	dt, err = time.Parse(util.DateTimeFormat, modified)
	if err != nil {
		return nil, fmt.Errorf("getRowMedia time.Parse 2 error: %v", err)
	}
	m.Modified = DateTime(dt)
	m.Public = public == 1
	if deleted.Valid && len(deleted.String) > 0 {
		dt, err = time.Parse(util.DateTimeFormat, deleted.String)
		if err != nil {
			return nil, fmt.Errorf("getRowMedia time.Parse 3 error: %v", err)
		}
		dd := DateTime(dt)
		m.Deleted = &dd
	}
	if meta.Valid && len(meta.String) > 0 {
		if err := json.Unmarshal([]byte(meta.String), m.Meta); err != nil {
			return nil, fmt.Errorf("getRowMedia json.Unmarshal error: %v", err)
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
		return nil, fmt.Errorf("GetUsers getDB error: %v", err)
	}
	row, err := db.Query(fmt.Sprintf(`SELECT %s
	FROM user`, userFields))
	defer row.Close()
	var result []*User
	for row.Next() {
		u, err := getRowUser(row)
		if err != nil {
			return nil, fmt.Errorf("GetUsers getRowUser error: %v", err)
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
		return nil, fmt.Errorf("GetUser db.Query error: %v", err)
	}
	for row.Next() {
		u, err := getRowUser(row)
		if err != nil {
			return nil, fmt.Errorf("GetUser getRowUser error: %v", err)
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
			return fmt.Errorf("saveUser db.Exec error: %v", err)
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
	if err != nil {
		return fmt.Errorf("saveUser db.Exec 2 error: %v", err)
	}
	return nil
}
