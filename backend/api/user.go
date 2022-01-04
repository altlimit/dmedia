package api

import (
	"fmt"
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
		code := s.QueryParam(r, "code")
		user := &model.User{Name: req.Name}
		if err := user.SetPassword(req.Password); err != nil {
			return err
		}
		if u.IsAdmin || code == adminCode {
			user.Active = req.Active
			user.IsAdmin = req.IsAdmin || code == adminCode
		} else if code == userCode {
			user.IsAdmin = false
			user.Active = true
		} else {
			if code != "" {
				return newValidationErr("code", "invalid")
			}
			return errAuth
		}
		if err := user.Save(); err != nil {
			if err.Error() == "UNIQUE constraint failed: user.name" {
				return newValidationErr("username", "exists")
			}
			return err
		}
		user.Password = ""
		return user
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
				if err := user.SetPassword(req.Password); err != nil {
					return err
				}
			}
			user.IsAdmin = req.IsAdmin
			user.Active = req.IsAdmin
			u = user
		} else if user.ID == u.ID {
			if req.Name != "" {
				user.Name = req.Name
			}
			if req.Password != "" {
				if err := user.SetPassword(req.Password); err != nil {
					return err
				}
			}
		} else {
			return errAuth
		}
		s.Cache.Delete(fmt.Sprintf("user:%d", user.ID))
		if err := user.Save(); err != nil {
			return err
		}
		u.Password = ""
		return u
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
		return s.cursor(users, 1)
	})
}

func (s *Server) handleAuth() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		u := s.currentUser(r.Context())
		u.Password = ""
		return u
	})
}
