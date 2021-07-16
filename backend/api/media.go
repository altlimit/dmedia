package api

import (
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

func (s *Server) handleGetAllMedia() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		u := s.currentUser(r.Context())
		page, _ := strconv.Atoi(s.QueryParam(r, "p"))
		limit, _ := strconv.Atoi(s.QueryParam(r, "l"))
		if limit <= 0 || limit > 100 {
			limit = 20
		}
		if page <= 0 {
			page = 1
		}
		medias, total, err := u.GetAllMedia(page, limit)
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
		id, err := strconv.Atoi(mux.Vars(r)["id"])
		if err != nil {
			return err
		}
		media, err := u.GetMediaByID(id)
		if err != nil {
			return err
		}
		return media
	})
}
