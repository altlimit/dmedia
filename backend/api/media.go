package api

import (
	"math"
	"net/http"
	"strconv"
	"strings"

	"github.com/altlimit/dmedia/sync"
	"github.com/altlimit/dmedia/util"
	"github.com/gorilla/mux"
)

func (s *Server) handleGetAllMedia() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		u := s.currentUser(r.Context())
		deleted := s.QueryParam(r, "deleted")
		page, _ := strconv.Atoi(s.QueryParam(r, "p"))
		limit, _ := strconv.Atoi(s.QueryParam(r, "l"))
		if limit <= 0 || limit > 100 {
			limit = 100
		}
		if page <= 0 {
			page = 1
		}
		medias, total, err := u.GetAllMedia(deleted == "1", page, limit)
		if err != nil {
			return err
		}
		pages := int(math.Ceil(float64(total) / float64(limit)))
		if pages <= 0 {
			pages = 1
		}
		return s.cursor(medias, pages)
	})
}

func (s *Server) handleGetMedia() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		u := s.currentUser(r.Context())
		id := util.Atoi64(mux.Vars(r)["id"])
		media, err := u.GetMediaByID(id)
		if err != nil {
			return err
		}
		return media
	})
}

func (s *Server) handleRestoreMedia() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		u := s.currentUser(r.Context())
		ids := strings.Split(mux.Vars(r)["id"], "-")
		var intIds []int64
		for _, id := range ids {
			intIds = append(intIds, util.Atoi64(id))
		}
		if err := u.RestoreMediaById(intIds); err != nil {
			return err
		}
		return nil
	})
}

func (s *Server) handleDeleteMedia() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		u := s.currentUser(r.Context())
		ids := strings.Split(mux.Vars(r)["id"], "-")
		var intIds []int64
		for _, id := range ids {
			intIds = append(intIds, util.Atoi64(id))
		}
		if err := u.DeleteMediaById(intIds); err != nil {
			return err
		}
		go sync.ScheduleSync(u.ID)
		return nil
	})
}
