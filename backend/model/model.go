package model

import (
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
	_ "github.com/mattn/go-sqlite3"
)

var (
	openedDBs map[string]*DB
	dbLock    sync.Mutex
	mdbLock   sync.Mutex
	mData     *mainData

	ErrNotFound     = fmt.Errorf("not found")
	ErrNotSupported = fmt.Errorf("not supported")
)

type (
	DB struct {
		db         *sql.DB
		lastAccess time.Time
	}

	User struct {
		Name     string `json:"username"`
		Password string `json:"password"`
		Schema   int    `json:"schema"`
		IsAdmin  bool   `json:"admin"`
	}

	mainData struct {
		Users []*User `json:"users"`
	}
)

func dataPath(user string) string {
	dp := util.DataPath
	if user != "" {
		dp = filepath.Join(dp, user)
	}
	os.MkdirAll(dp, os.ModeDir)
	return dp
}

func getDB(user string) (*sql.DB, error) {
	dbLock.Lock()
	defer dbLock.Unlock()
	odb, ok := openedDBs[user]
	if ok {
		odb.lastAccess = time.Now().UTC()
		return odb.db, nil
	}

	log.Printf("Opening %s DB", user)
	p := filepath.Join(dataPath(user), "media.db")
	db, err := sql.Open("sqlite3", p)
	db.SetMaxOpenConns(1)
	if err != nil {
		return nil, err
	}
	if openedDBs == nil {
		openedDBs = make(map[string]*DB)
	}
	openedDBs[user] = &DB{db: db, lastAccess: time.Now().UTC()}
	go func() {
		for {
			time.Sleep(time.Minute * 1)
			idle := false
			dbLock.Lock()
			db, ok := openedDBs[user]
			if !ok || time.Now().UTC().Sub(db.lastAccess).Minutes() > 1 {
				idle = true
			}
			dbLock.Unlock()
			if idle {
				break
			}
		}
		log.Printf("Closing %s DB", user)
		db.Close()
		dbLock.Lock()
		defer dbLock.Unlock()
		delete(openedDBs, user)
	}()

	// check migrations
	u, err := GetUser(user)
	if err != nil {
		return nil, err
	}
	tdb := len(dbMigrations)
	if tdb > u.Schema {
		for i := u.Schema; i < tdb; i++ {
			_, err = db.Exec(dbMigrations[i])
			if err != nil {
				return nil, err
			}
		}
		u.Schema = tdb
		if err := u.Save(); err != nil {
			return nil, err
		}
	}
	return db, nil
}

func GetUsers() ([]*User, error) {
	if err := loadMainData(); err != nil {
		return nil, err
	}
	return mData.Users, nil
}

func GetUser(username string) (*User, error) {
	if err := loadMainData(); err != nil {
		return nil, err
	}
	for _, v := range mData.Users {
		if strings.ToLower(username) == strings.ToLower(v.Name) {
			return v, nil
		}
	}
	return nil, ErrNotFound
}

func saveUser(user *User) error {
	mdbLock.Lock()
	defer mdbLock.Unlock()
	if err := loadMainData(); err != nil {
		return err
	}

	found := false
	for k, v := range mData.Users {
		if strings.ToLower(v.Name) == strings.ToLower(user.Name) {
			found = true
			mData.Users[k] = user
			break
		}
	}
	if !found {
		mData.Users = append(mData.Users, user)
	}
	dat, err := json.Marshal(mData)
	if err != nil {
		return err
	}
	return ioutil.WriteFile(filepath.Join(dataPath(""), "main.json"), dat, 0644)
}

func loadMainData() error {
	if mData == nil {
		mdbLock.Lock()
		defer mdbLock.Unlock()
		mData = &mainData{Users: make([]*User, 0)}
		dp := dataPath("")
		mdp := filepath.Join(dp, "main.json")
		if !util.FileExists(mdp) {
			admin := &User{IsAdmin: true, Name: "admin"}
			pw, err := uid.Generate()
			if err != nil {
				return err
			}
			admin.SetPassword(pw)
			mData.Users = append(mData.Users, admin)
			dat, err := json.Marshal(mData)
			if err != nil {
				return err
			}
			if err := ioutil.WriteFile(mdp, dat, 0644); err != nil {
				return err
			}
			log.Printf("Created User: %s / %s", admin.Name, pw)
		}
		dat, err := ioutil.ReadFile(mdp)
		if err != nil {
			return err
		}
		return json.Unmarshal(dat, mData)
	}
	return nil
}
