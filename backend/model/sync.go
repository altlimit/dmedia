package model

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
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

	SyncMedia struct {
		ID         int64  `json:"id" db:"id"`
		LocationID int64  `json:"location_id" db:"location_id"`
		MediaID    int64  `json:"media_id" db:"media_id"`
		Meta       string `json:"meta" db:"meta"`
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

func GetSyncs(userID int64, all bool) ([]SyncLocation, error) {
	db, err := getDB(userID)
	if err != nil {
		return nil, fmt.Errorf("GetSyncs getDB error: %v", err)
	}
	var where string
	if !all {
		where = " WHERE deleted IS NULL"
	}
	syncs := []SyncLocation{}
	if err = db.Select(&syncs, fmt.Sprintf(`SELECT * FROM sync_location %s`, where)); err != nil {
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

func GetMediaToSync(userID int64, loc *SyncLocation) ([]Media, []SyncMedia, error) {
	db, err := getDB(userID)
	if err != nil {
		return nil, nil, fmt.Errorf("GetMediaToSync getDB error %v", err)
	}
	medias := []Media{}
	toDelete := []SyncMedia{}
	if loc.Deleted == nil {
		if err := db.Select(&medias, `SELECT * FROM media WHERE id NOT IN(
			SELECT media_id FROM sync_media WHERE location_id = $1
		) ORDER BY created`, loc.ID); err != nil {
			return nil, nil, fmt.Errorf("GetMediaToSync select error %v", err)
		}
		if err := db.Select(&toDelete, `SELECT * FROM sync_media
			WHERE
				location_id = $1 AND
				media_id NOT IN(
				SELECT id FROM media
			)`, loc.ID); err != nil {
			return nil, nil, fmt.Errorf("GetMediaToSync select meta error %v", err)
		}
	} else {
		if err := db.Select(&toDelete, `SELECT * FROM sync_media
		WHERE
			location_id = $1`, loc.ID); err != nil {
			return nil, nil, fmt.Errorf("GetMediaToSync select * meta error %v", err)
		}
	}
	return medias, toDelete, nil
}

func UpdateSyncMedia(userID int64, loc *SyncLocation, syncMedias []SyncMedia, deletedMedias []SyncMedia) error {
	db, err := getDB(userID)
	if err != nil {
		return fmt.Errorf("UpdateSyncMedia getDB error %v", err)
	}
	tx, err := db.Beginx()
	if err != nil {
		return fmt.Errorf("UpdateSyncMedia Beginx error %v", err)
	}
	for _, sm := range syncMedias {
		if _, err := tx.NamedExec(`INSERT INTO sync_media(location_id, media_id, meta)
			VALUES (:location_id, :media_id, :meta)`, sm); err != nil {
			return fmt.Errorf("UpdateSyncMedia insert err %v -> Rollback: %v", err, tx.Rollback())
		}
	}
	var delIDs []string
	for _, dm := range deletedMedias {
		delIDs = append(delIDs, strconv.FormatInt(dm.ID, 10))
	}
	if len(delIDs) > 0 {
		if _, err := tx.Exec(fmt.Sprintf(`DELETE FROM sync_media WHERE id IN (%s)`, strings.Join(delIDs, ","))); err != nil {
			return fmt.Errorf("UpdateSyncMedia delete error %v -> Rollback: %v", err, tx.Rollback())
		}
	}
	if loc.Deleted != nil {
		if _, err := tx.Exec(`DELETE FROM sync_location WHERE id = $1`, loc.ID); err != nil {
			return fmt.Errorf("UpdateSyncMedia delete loc err %v -> Rollback: %v", err, tx.Rollback())
		}
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("UpdateSyncMedia commit error %v -> Rollback: %v", err, tx.Rollback())
	}
	return nil
}
