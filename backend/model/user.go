package model

import (
	"bytes"
	"crypto/sha1"
	"database/sql"
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"time"

	"github.com/altlimit/dmedia/util"
	"github.com/rwcarlsen/goexif/exif"
	"github.com/rwcarlsen/goexif/tiff"
	"golang.org/x/crypto/bcrypt"
)

var (
	sBool = map[bool]int{true: 1, false: 0}
)

type (
	DateTime time.Time
	User     struct {
		ID       int64    `json:"id" db:"id"`
		Name     string   `json:"username" db:"name" validate:"required"`
		Password string   `json:"password,omitempty" db:"password"`
		IsAdmin  bool     `json:"admin" db:"admin"`
		Active   bool     `json:"active" db:"active"`
		Created  DateTime `json:"-" db:"created"`
	}

	Media struct {
		ID          int64     `json:"id" db:"id"`
		Name        string    `json:"name" db:"name"`
		Public      bool      `json:"public" db:"public"`
		Checksum    string    `json:"checksum" db:"checksum"`
		ContentType string    `json:"ctype" db:"ctype"`
		Created     DateTime  `json:"created" db:"created"`
		Modified    DateTime  `json:"modified" db:"modified"`
		Deleted     *DateTime `json:"deleted" db:"deleted"`
		Size        int       `json:"size" db:"size"`
		Meta        *Meta     `json:"meta" db:"meta"`
	}

	Meta struct {
		Exif interface{} `json:"exif,omitempty"`
		Info interface{} `json:"info,omitempty"`
	}
	ExifData struct {
		Data map[string]*tiff.Tag
	}
)

func (m *Meta) Scan(src interface{}) error {
	switch t := src.(type) {
	case []byte:
		if t == nil {
			return nil
		}
		return json.Unmarshal(t, &m)
	case string:
		if t == "" {
			return nil
		}
		return json.Unmarshal([]byte(t), &m)
	default:
		return ErrInvalidType
	}
}

func (m *Meta) Value() (driver.Value, error) {
	return json.Marshal(m)
}

func (t *DateTime) Scan(src interface{}) error {
	switch tt := src.(type) {
	case time.Time:
		*t = DateTime(tt)
		return nil
	case string:
		if tt == "" {
			return nil
		}
		dt, err := time.Parse(util.DateTimeFormat, tt)
		if err == nil {
			*t = DateTime(dt)
		}
		return err
	default:
		log.Println("Type", reflect.TypeOf(src))
		return ErrInvalidType
	}
}

func (t *DateTime) Value() (driver.Value, error) {
	return time.Time(*t).Format(util.DateTimeFormat), nil
}

func (t DateTime) MarshalJSON() ([]byte, error) {
	stamp := fmt.Sprintf("\"%s\"", time.Time(t).Format(util.DateTimeFormat))
	return []byte(stamp), nil
}

func (t *DateTime) UnmarshalJSON(b []byte) error {
	s := strings.Trim(string(b), "\"")
	dt, err := time.Parse(util.DateTimeFormat, s)
	if err == nil {
		ddt := DateTime(dt)
		*t = ddt
	}
	return err
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
		createdTime, _ = util.TimeFromString(name)
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

func (u *User) GetAllMedia(deleted bool, page int, limit int) ([]Media, int, error) {
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
	allMedia := []Media{}
	err = db.Select(&allMedia, fmt.Sprintf(`
		SELECT *
		FROM media
		%s
		ORDER BY created DESC
		LIMIT %d
		OFFSET %d
	`, where, limit, (limit*page)-limit), args...)
	if err != nil {
		return nil, 0, fmt.Errorf("GetAllMedia db select error: %v", err)
	}
	var total int
	if err := db.Get(&total, `SELECT COUNT(1) FROM media`); err != nil {
		return nil, 0, fmt.Errorf("GetAllMedia select count error %v", err)
	}
	return allMedia, total, nil
}

func (u *User) GetMediaByID(id int64) (*Media, error) {
	db, err := getDB(u.ID)
	if err != nil {
		return nil, fmt.Errorf("GetMediaByID getDB error: %v", err)
	}
	media := &Media{}
	err = db.Get(media, `
		SELECT *
		FROM media
		WHERE id = ?
		LIMIT 1
	`, id)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("GetMediaByID db get error: %v", err)
	}
	return media, nil
}

func (u *User) RestoreMediaById(ids []int64) error {
	db, err := getDB(u.ID)
	if err != nil {
		return fmt.Errorf("RestoreMediaById getDB error: %v", err)
	}
	cleanIDs := strings.Join(util.Int64ToStrings(ids), ",")
	_, err = db.Exec(fmt.Sprintf(`
		UPDATE media
		SET
			modified=CURRENT_TIMESTAMP,
			deleted=NULL
		WHERE id IN (%s);
	`, cleanIDs))
	if err != nil {
		return fmt.Errorf("RestoreMediaById db.Query error: %v", err)
	}
	return nil
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
	medias := []Media{}
	err = db.Select(&medias, fmt.Sprintf(`
		SELECT *
		FROM media
		WHERE id IN (%s)
	`, cleanIDs))
	if err != nil {
		return fmt.Errorf("DeleteMediaById db.Query error: %v", err)
	}
	rowCtr := 0
	for _, m := range medias {
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

func GetUsers() ([]User, error) {
	db, err := getDB(0)
	if err != nil {
		return nil, fmt.Errorf("GetUsers getDB error: %v", err)
	}
	users := []User{}
	if err = db.Select(&users, `SELECT * FROM user`); err != nil {
		return nil, fmt.Errorf("GetUsers select error %v", err)
	}
	return users, nil
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
	user := &User{}
	err = db.Get(user, fmt.Sprintf(`SELECT *
	FROM user
	WHERE %s = ?`, field), val)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("GetUser db get error: %v", err)
	}
	return user, nil
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
