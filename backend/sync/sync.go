package sync

import (
	"log"

	"github.com/altlimit/dmedia/model"
)

type (
	Sync interface {
		Valid() bool
		Upload(cType string, path string) (string, error)
		Delete(meta string) error
	}
)

var (
	SyncChannel = make(chan int64)
)

func syncListener() {
	log.Println("Started sync listener")
	for {
		userID := <-SyncChannel
		SyncUser(userID)
	}
}

func Init() {
	go syncListener()

	users, err := model.GetUsers()
	if err != nil {
		log.Fatalf("sync get users error %v", err)
	}

	for _, u := range users {
		go func(uID int64) {
			SyncChannel <- uID
		}(u.ID)
	}
	log.Println("Initialized sync for", len(users), "users")
}

func ScheduleSync(userID int64) {
	SyncChannel <- userID
}

func SyncUser(userID int64) {
	locs, err := model.GetSyncs(userID, true)
	if err != nil {
		log.Printf("SyncUser error get syncs %v", err)
		return
	}

	for _, loc := range locs {
		var syncer Sync
		if loc.Type == "telegram" {
			syncer = &Telegram{
				Token:   loc.Config["token"].(string),
				Channel: loc.Config["channel"].(string),
			}
		}
		if syncer == nil {
			log.Println("SyncUser", userID, "location type", loc.Type, "invalid")
			continue
		} else if !syncer.Valid() {
			log.Println("SyncUser", userID, "invalid config", loc.Name)
			continue
		}
		go SyncLocation(userID, &loc, syncer)
	}
}

func SyncLocation(userID int64, loc *model.SyncLocation, syncer Sync) {
	medias, delMedias, err := model.GetMediaToSync(userID, loc)
	if err != nil {
		log.Println("SyncLocation[", userID, "][", loc.ID, loc.Name, "] get sync error ", err)
		return
	}
	toUpload := len(medias)
	toDelete := len(delMedias)
	log.Println("SyncLocation[", userID, "][", loc.ID, loc.Name, "]", toUpload, "# to upload", toDelete, "# to delete")
	var (
		addSync      []model.SyncMedia
		delSync      []model.SyncMedia
		uploaded     int
		failedUpload int
		deleted      int
		failedDelete int
	)
	for _, m := range medias {
		meta, err := syncer.Upload(m.ContentType, m.Path(userID))
		if err != nil {
			log.Println("SyncLocation[", userID, "][", loc.ID, loc.Name, "] upload", m.ID, "error", err)
			failedUpload++
			continue
		}
		uploaded++
		log.Println("SyncLocation[", userID, "][", loc.ID, loc.Name, "] uploaded", m.ID, "progress", uploaded, "/", toUpload, "failed", failedUpload)
		addSync = append(addSync, model.SyncMedia{
			LocationID: loc.ID,
			MediaID:    m.ID,
			Meta:       meta,
		})
	}
	for _, sm := range delMedias {
		err = syncer.Delete(sm.Meta)
		if err != nil {
			log.Println("SyncLocation[", userID, "][", loc.ID, loc.Name, "] delete", sm.MediaID, "error", err)
			failedDelete++
			continue
		}
		deleted++
		log.Println("SyncLocation[", userID, "][", loc.ID, loc.Name, "] deleted", sm.MediaID, "progress", deleted, "/", toDelete, "failed", failedDelete)
		delSync = append(delSync, sm)
	}

	for i := 0; i < 3; i++ {
		if err := model.UpdateSyncMedia(userID, loc, addSync, delSync); err != nil {
			log.Println("SyncLocation[", userID, "][", loc.ID, loc.Name, "] update failed", err)
			continue
		}
		break
	}
}
