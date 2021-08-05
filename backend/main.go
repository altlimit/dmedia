// +build json1
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"github.com/altlimit/dmedia/api"
	"github.com/altlimit/dmedia/util"
	"gopkg.in/natefinch/lumberjack.v2"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "5454"
	}

	if os.Getenv("LOGFILE") != "" {
		log.SetOutput(&lumberjack.Logger{
			Filename:   filepath.Join(util.DataPath, "logs", "dmedia.log"),
			MaxSize:    10,
			MaxBackups: 3,
			MaxAge:     15,
			Compress:   true,
		})
	}

	srv := &http.Server{
		Handler: api.NewServer(),
		Addr:    fmt.Sprintf(":%s", port),
	}
	log.Printf("DMedia Running at: http://localhost:%s", port)
	log.Fatal(srv.ListenAndServe())
}
