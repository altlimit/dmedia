package api

import (
	"net/http"

	"github.com/altlimit/dmedia/model"
	"github.com/altlimit/dmedia/util"
	"github.com/gorilla/mux"
)

func (s *Server) handleCreateSyncLocation() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		req := &model.SyncLocation{}
		if err := s.bind(r, req); err != nil {
			return err
		}
		ctx := r.Context()
		u := s.currentUser(ctx)
		if err := req.Save(u); err != nil {
			return err
		}
		return req
	})
}

func (s *Server) handleSaveSyncLocation() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		req := &model.SyncLocation{}
		if err := s.bind(r, req); err != nil {
			return err
		}
		ctx := r.Context()
		u := s.currentUser(ctx)
		locID := util.Atoi64(mux.Vars(r)["id"])
		loc, err := model.GetSyncLocation(u.ID, locID)
		if err != nil {
			return err
		}
		loc.Name = req.Name
		loc.Type = req.Type
		loc.Config = req.Config
		loc.Deleted = req.Deleted
		if err := loc.Save(u); err != nil {
			return err
		}
		return loc
	})
}
