package api

import (
	"image/jpeg"
	"io"
	"log"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/altlimit/dmedia/util"
	"github.com/gorilla/mux"
	resizer "github.com/nfnt/resize"
)

func resizeImage(w io.Writer, fPath string, width uint) error {
	file, err := os.Open(fPath)
	if err != nil {
		return err
	}

	img, err := jpeg.Decode(file)
	if err != nil {
		return err
	}
	file.Close()

	m := resizer.Resize(width, 0, img, resizer.Lanczos3)
	return jpeg.Encode(w, m, nil)
}

func (s *Server) handleDownload() http.HandlerFunc {
	fs := http.FileServer(http.Dir(util.DataPath))
	return func(wr http.ResponseWriter, r *http.Request) {
		v := mux.Vars(r)
		if v["user"] != util.I64toa(s.userID(r.Context())) {
			s.writeError(wr, errAuth)
			return
		}
		size := s.QueryParam(r, "size")
		p := filepath.Join(util.DataPath, r.URL.Path)
		if size != "" {
			cType := mime.TypeByExtension(filepath.Ext(p))
			log.Printf("ContentType: %s", cType)
			if strings.Index(cType, "image/") != 0 {
				np := p + ".jpg"
				if !util.FileExists(np) {
					if err := util.Thumbnail(p); err != nil {
						s.writeError(wr, err)
						return
					}
				}
				p = np
			}
			sz, err := strconv.Atoi(size)
			if err != nil {
				s.writeError(wr, err)
				return
			}
			if err := resizeImage(wr, p, uint(sz)); err != nil {
				s.writeError(wr, err)
				return
			}
			return
		}
		fs.ServeHTTP(wr, r)
	}
}
