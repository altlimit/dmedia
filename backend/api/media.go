package api

import (
	"net/http"
	"strconv"

	"github.com/altlimit/dmedia/util"
	"github.com/gorilla/mux"
)

func (s *Server) handleGetAllMedia() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		u := s.currentUser(r.Context())
		lastModified := s.QueryParam(r, "mod")
		page, _ := strconv.Atoi(s.QueryParam(r, "p"))
		limit, _ := strconv.Atoi(s.QueryParam(r, "l"))
		if limit <= 0 || limit > 100 {
			limit = 100
		}
		if page <= 0 {
			page = 1
		}
		medias, total, err := u.GetAllMedia(lastModified, page, limit)
		if err != nil {
			return err
		}
		pages := total / limit
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
