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
		if u == nil {
			return errAuth
		}
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
		if u == nil {
			return errAuth
		}
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

func (s *Server) handleGetSync() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		ctx := r.Context()
		u := s.currentUser(ctx)
		if u == nil {
			return errAuth
		}
		syncs, err := model.GetSyncs(u.ID)
		if err != nil {
			return err
		}
		return s.cursor(syncs, 1)
	})
}

func (s *Server) handleDeleteSync() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		u := s.currentUser(r.Context())
		if u == nil {
			return errAuth
		}
		locID := util.Atoi64(mux.Vars(r)["id"])
		return model.DeleteSyncByID(u.ID, locID)
	})
}
