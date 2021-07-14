package api

import (
	"net/http"

	"github.com/altlimit/dmedia/model"
)

func (s *Server) handleSaveUser() http.HandlerFunc {
	type request struct {
		Username string `json:"username" validate:"required,username"`
		Password string `json:"password" validate:"required"`
		Admin    bool   `json:"admin"`
	}
	return s.handler(func(r *http.Request) interface{} {
		var req request
		err := s.bind(r, &req)
		if err != nil {
			return err
		}
		ctx := r.Context()
		u := s.currentUser(ctx)
		if u.IsAdmin {
			u, err = model.GetUser(req.Username)
			if err == model.ErrNotFound {
				u = &model.User{Name: req.Username}
			}
			u.SetPassword(req.Password)
			u.IsAdmin = req.Admin
		} else if u.Name == req.Username {
			u.SetPassword(req.Password)
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
		return "OK"
	})
}
