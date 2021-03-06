package model

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/altlimit/dmedia/util"
	"github.com/jmoiron/sqlx"
	_ "github.com/mattn/go-sqlite3"
)

var (
	openedDBs map[int64]*DB
	dbLock    sync.Mutex

	ErrNotFound     = fmt.Errorf("not found")
	ErrNotSupported = fmt.Errorf("not supported")
)

type (
	DB struct {
		db         *sqlx.DB
		lastAccess time.Time
	}
)

func dataPath(userID int64) string {
	dp := util.DataPath
	u := util.I64toa(userID)
	dp = filepath.Join(dp, u)
	os.MkdirAll(dp, 0755)
	return dp
}

func getDB(userID int64) (*sqlx.DB, error) {
	dbLock.Lock()
	defer dbLock.Unlock()
	odb, ok := openedDBs[userID]
	if ok {
		odb.lastAccess = time.Now().UTC()
		return odb.db, nil
	}
	var p string
	if userID > 0 {
		log.Printf("Opening %d.db", userID)
		p = filepath.Join(dataPath(userID), "media.db")
	} else {
		log.Printf("Opening main.db")
		p = filepath.Join(util.DataPath, "main.db")
	}
	db, err := sqlx.Open("sqlite3", p)
	db.SetMaxOpenConns(1)
	if err != nil {
		return nil, fmt.Errorf("getDB sql.Open error: %v", err)
	}
	if openedDBs == nil {
		openedDBs = make(map[int64]*DB)
	}
	openedDBs[userID] = &DB{db: db, lastAccess: time.Now().UTC()}
	go func() {
		for {
			time.Sleep(time.Minute * 1)
			idle := false
			dbLock.Lock()
			db, ok := openedDBs[userID]
			if !ok || time.Now().UTC().Sub(db.lastAccess).Minutes() > 1 {
				idle = true
			}
			dbLock.Unlock()
			if idle {
				break
			}
		}
		log.Printf("Closing %d.db", userID)
		db.Close()
		dbLock.Lock()
		defer dbLock.Unlock()
		delete(openedDBs, userID)
	}()

	// check migrations
	var migrations []string
	if userID == 0 {
		migrations = dbMigrations
	} else {
		migrations = mediaMigrations
	}
	tdb := len(migrations)
	r := db.QueryRow(`SELECT version FROM migrations`)
	var version int
	if err := r.Scan(&version); err != nil {
		if err.Error() == "no such table: migrations" {
			_, err = db.Exec(dbMigrateTable)
			if err != nil {
				return nil, fmt.Errorf("getDB db.Exec 1 error: %v", err)
			}
		} else {
			return nil, fmt.Errorf("getDB r.Scan error: %v", err)
		}
	}
	if tdb > version {
		for i := version; i < tdb; i++ {
			_, err = db.Exec(migrations[i])
			if err != nil {
				return nil, fmt.Errorf("getDB db.Exec 2 error: %v", err)
			}
		}
		if _, err := db.Exec(`UPDATE migrations SET version = ?`, tdb); err != nil {
			return nil, fmt.Errorf("getDB db.Exec 3 error: %v", err)
		}
		log.Printf("Migrated db to %d", tdb)
	}
	return db, nil
}
