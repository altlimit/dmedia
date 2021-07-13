package api

import (
	"io/ioutil"
	"log"
	"net/http"
)

func (s *Server) handleUpload() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		r.ParseMultipartForm(1 << 20)
		var (
			cType   string
			content []byte
		)
		fName := r.FormValue("name")
		// fetch from URL
		blobURL := r.FormValue("url")
		if blobURL != "" {
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
		log.Printf("%s - %d", cType, len(content))
		return "OK"
	})
}
