package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/altlimit/dmedia/api"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "5454"
	}
	srv := &http.Server{
		Handler:      api.NewServer(),
		Addr:         fmt.Sprintf(":%s", port),
		WriteTimeout: 15 * time.Second,
		ReadTimeout:  15 * time.Second,
	}
	log.Printf("DMedia Running at: http://localhost:%s", port)
	log.Fatal(srv.ListenAndServe())
}
