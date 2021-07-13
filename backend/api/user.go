package api

import (
	"net/http"

	"github.com/altlimit/dmedia/model"
)

func (s *Server) handleCreateUser() http.HandlerFunc {
	type request struct {
		Username string `json:"username" validate:"required,username"`
		Password string `json:"password" validate:"required"`
	}
	return s.handler(func(r *http.Request) interface{} {
		var req request
		if err := s.bind(r, &req); err != nil {
			return err
		}
		u := &model.User{Name: req.Username}
		u.SetPassword(req.Password)
		return u.Save()
	})
}

func (s *Server) handleGetUser() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		users, err := model.GetUsers()
		if err != nil {
			return err
		}
		return users
	})
}
