package api

import (
	"bufio"
	"bytes"
	"image/jpeg"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

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
			item, err := s.Cache.Fetch("dl:"+size+":"+r.URL.Path, time.Hour*24, func() (interface{}, error) {
				cType := util.TypeByExt(filepath.Ext(p))
				if strings.Index(cType, "image/") != 0 {
					np := p + ".jpg"
					if !util.FileExists(np) {
						if err := util.Thumbnail(p); err != nil {
							return nil, err
						}
					}
					p = np
				}
				sz, err := strconv.Atoi(size)
				if err != nil {
					return nil, err
				}
				var b bytes.Buffer
				br := bufio.NewWriter(&b)
				if err := resizeImage(br, p, uint(sz)); err != nil {
					return nil, err
				}
				return b.Bytes(), nil
			})
			if err != nil {
				s.writeError(wr, err)
				return
			}
			b := item.Value().([]byte)
			wr.Header().Set("Content-Type", "image/jpeg")
			wr.Header().Set("Content-Length", strconv.Itoa(len(b)))
			if _, err := wr.Write(b); err != nil {
				s.writeError(wr, err)
			}
			return
		}
		fs.ServeHTTP(wr, r)
	}
}
