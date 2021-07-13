package model

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path"
	"strings"
	"sync"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

var (
	openedDBs map[string]*DB
	dbLock    sync.Mutex
	mdbLock   sync.Mutex
	mData     *mainData
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
	}

	mainData struct {
		Users []*User `json:"users"`
	}
)

func dataPath() string {
	dp := path.Join("..", "data")
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
	p := path.Join(dataPath(), user+".db")
	db, err := sql.Open("sqlite3", p)
	db.SetMaxOpenConns(1)
	if err != nil {
		return nil, err
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
	}()

	// check migrations
	u, err := GetUser(user)
	if err != nil {
		return nil, err
	}
	tdb := len(dbMigrations)
	if tdb > u.Schema {
		for i := u.Schema; i <= tdb; i++ {
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
	return nil, fmt.Errorf("User: %s not found", username)
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
	return ioutil.WriteFile(path.Join(dataPath(), "main.json"), dat, 0644)
}

func loadMainData() error {
	if mData == nil {
		mdbLock.Lock()
		defer mdbLock.Unlock()
		mData = &mainData{Users: make([]*User, 0)}
		dp := dataPath()
		mdp := path.Join(dp, "main.json")
		if fileExists(mdp) {
			dat, err := ioutil.ReadFile(mdp)
			if err != nil {
				return err
			}
			return json.Unmarshal(dat, mData)
		}
	}
	return nil
}

func fileExists(path string) bool {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return false
	}
	return true
}
