package model

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
)

var (
	ErrInvalidType = errors.New("invalid type")
)

type (
	SyncConfig map[string]interface{}

	SyncLocation struct {
		ID      int64      `json:"id" db:"id"`
		Name    string     `json:"name" db:"name" validate:"required"`
		Type    string     `json:"type" db:"stype" validate:"required"`
		Deleted *DateTime  `json:"deleted,omitempty" db:"deleted"`
		Config  SyncConfig `json:"config" db:"config" validate:"required"`
	}
)

func (sc *SyncConfig) Scan(src interface{}) error {
	switch t := src.(type) {
	case []byte:
		return json.Unmarshal(t, &sc)
	case string:
		return json.Unmarshal([]byte(t), &sc)
	default:
		return ErrInvalidType
	}
}

func (sc *SyncConfig) Value() (driver.Value, error) {
	return json.Marshal(sc)
}

func (s *SyncLocation) Save(u *User) error {
	return saveSyncLocation(u.ID, s)
}

func saveSyncLocation(userID int64, syncLoc *SyncLocation) error {
	db, err := getDB(userID)
	if err != nil {
		return err
	}
	conf, _ := json.Marshal(syncLoc.Config)
	args := []interface{}{syncLoc.Name, syncLoc.Type, conf}
	if syncLoc.ID == 0 {
		res, err := db.Exec(`
		insert into sync_location(name, stype, config)
		values($1, $2, $3)`, args...)
		if err != nil {
			return fmt.Errorf("saveSyncLocation db insert error: %v", err)
		}
		id, err := res.LastInsertId()
		if err == nil {
			syncLoc.ID = id
		}
	} else {
		args = append(args, syncLoc.Deleted)
		args = append(args, syncLoc.ID)
		_, err = db.Exec(`
		UPDATE sync_location SET
		name = $1,
		stype = $2,
		config = $3,
		deleted = $4
		WHERE id = $5
		`, args...)
	}
	if err != nil {
		return fmt.Errorf("saveUser db update error: %v", err)
	}
	return nil
}

func GetSyncLocation(userID int64, locID int64) (*SyncLocation, error) {
	db, err := getDB(userID)
	if err != nil {
		return nil, err
	}
	loc := &SyncLocation{}
	if err := db.Get(loc, `SELECT * FROM sync_location WHERE id = ?`, locID); err != nil {
		return nil, fmt.Errorf("GetSyncLocation error get %v", err)
	}
	return loc, nil
}

func GetSyncs(userID int64) ([]SyncLocation, error) {
	db, err := getDB(userID)
	if err != nil {
		return nil, fmt.Errorf("GetSyncs getDB error: %v", err)
	}
	syncs := []SyncLocation{}
	if err = db.Select(&syncs, `SELECT * FROM sync_location WHERE deleted IS NULL`); err != nil {
		return nil, fmt.Errorf("GetSyncs select error %v", err)
	}
	return syncs, nil
}

func DeleteSyncByID(userID int64, locID int64) error {
	db, err := getDB(userID)
	if err != nil {
		return fmt.Errorf("DeleteSyncByID getDB error: %v", err)
	}
	_, err = db.Exec(`DELETE FROM sync_location WHERE id = ?`, locID)
	if err != nil {
		return fmt.Errorf("DeleteSyncByID exec error %v", err)
	}
	return nil
}
