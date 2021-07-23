package api

import (
	"io/ioutil"
	"log"
	"net/http"
	"path"

	"github.com/altlimit/dmedia/model"
)

func (s *Server) handleUpload() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		r.ParseMultipartForm(1 << 20)
		var (
			cType   string
			content []byte
		)
		fName := r.FormValue("name")
		fallbackDate := r.FormValue("fallbackDate")
		// fetch from URL
		blobURL := r.FormValue("url")
		if blobURL != "" {
			if fName == "" {
				fName = path.Base(blobURL)
				if fName == "." || fName == "/" {
					fName = ""
				}
			}
			req, err := http.NewRequest(http.MethodGet, blobURL, nil)
			if err != nil {
				return err
			}
			client := &http.Client{}
			resp, err := client.Do(req)
			if err != nil {
				return err
			}
			defer resp.Body.Close()
			content, err = ioutil.ReadAll(resp.Body)
			if err != nil {
				return err
			}
			cType = resp.Header.Get("Content-Type")
		} else {
			file, handler, err := r.FormFile("file")
			if err != nil {
				return err
			}
			defer file.Close()
			cType = handler.Header.Get("Content-Type")
			if fName == "" {
				fName = handler.Filename
			}
			content, err = ioutil.ReadAll(file)
			if err != nil {
				return err
			}
		}
		if fName == "" {
			return newValidationErr("name", "required")
		}
		u, err := model.GetUser(s.userID(r.Context()), "")
		if err != nil {
			return err
		}
		log.Printf("Name;%s %s", fName, cType)
		id, err := u.AddMedia(fName, cType, content, fallbackDate)
		if err != nil {
			if err == model.ErrNotSupported {
				return newValidationErr("content_type", "not supported")
			}
			return err
		}
		return id
	})
}
