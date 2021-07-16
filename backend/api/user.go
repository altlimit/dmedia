package api

import (
	"net/http"

	"github.com/altlimit/dmedia/model"
	"github.com/altlimit/dmedia/util"
	"github.com/gorilla/mux"
)

func (s *Server) handleCreateUser() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		req := &model.User{}
		if err := s.bind(r, req); err != nil {
			return err
		}
		if req.Password == "" {
			return newValidationErr("password", "required")
		}
		ctx := r.Context()
		u := s.currentUser(ctx)
		aCode := s.QueryParam(r, "acode")
		uCode := s.QueryParam(r, "ucode")
		user := &model.User{Name: req.Name}
		user.SetPassword(req.Password)
		if u.IsAdmin || aCode == adminCode {
			user.Active = req.Active
			user.IsAdmin = req.IsAdmin
		} else if uCode == userCode {
			user.Active = true
		} else {
			return errAuth
		}
		return user.Save()
	})
}

func (s *Server) handleSaveUser() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		req := &model.User{}
		if err := s.bind(r, req); err != nil {
			return err
		}
		ctx := r.Context()
		u := s.currentUser(ctx)
		uid := util.Atoi64(mux.Vars(r)["id"])
		user, err := model.GetUser(uid, "")
		if err != nil {
			return err
		}
		if u.IsAdmin {
			if req.Name != "" {
				user.Name = req.Name
			}
			if req.Password != "" {
				user.Password = req.Password
			}
			user.IsAdmin = req.IsAdmin
			user.Active = req.IsAdmin
		} else if user.ID == u.ID {
			if req.Name != "" {
				user.Name = req.Name
			}
			if req.Password != "" {
				user.Password = req.Password
			}
		} else {
			return errAuth
		}
		return u.Save()
	})
}

func (s *Server) handleGetUser() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		if !s.currentUser(r.Context()).IsAdmin {
			return errAuth
		}
		users, err := model.GetUsers()
		if err != nil {
			return err
		}
		return users
	})
}

func (s *Server) handleAuth() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		u := s.currentUser(r.Context())
		u.Password = ""
		return u
	})
}
