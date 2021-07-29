package api

import (
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path"
	"path/filepath"

	"github.com/altlimit/dmedia/model"
	"github.com/altlimit/dmedia/util"
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

func (s *Server) handleUploadDir() http.HandlerFunc {
	return s.handler(func(r *http.Request) interface{} {
		ctx := r.Context()
		uploadDir := filepath.Join(util.DataPath, util.I64toa(s.userID(ctx)), "upload")
		if util.FileExists(uploadDir) {
			log.Printf("Found Upload Dir")
			u := s.currentUser(ctx)
			go func() {
				files, err := filePathWalkDir(uploadDir)
				if err != nil {
					log.Printf("Error Walk Dir: %v", err)
					return
				}
				for _, file := range files {
					id, err := u.AddMediaFromPath(file)
					log.Printf("AddMedia: %d -> Err: %v -> %s", id, err, file)
				}
			}()
		}
		return nil
	})
}

func filePathWalkDir(root string) ([]string, error) {
	var files []string
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if !info.IsDir() {
			files = append(files, path)
		}
		return nil
	})
	return files, err
}
