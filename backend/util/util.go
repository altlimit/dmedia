package util

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

var (
	DataPath  string
	ffmpegBin string
)

func init() {
	DataPath = os.Getenv("DATA_PATH")
	if DataPath == "" {
		DataPath = filepath.Join("..", "data")
	}
	ffmpegBin = os.Getenv("FFMPEG_BIN")
	if ffmpegBin == "" {
		panic(fmt.Errorf("FFMPEG_BIN set path of ffmpeg binary"))
	}
}

func FileExists(path string) bool {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return false
	}
	return true
}

func Thumbnail(input string) error {
	log.Printf("Genering thumb %s", input)
	out, err := exec.Command(ffmpegBin, "-i", input, "-ss", "00:00:01.000", "-vframes", "1", input+".jpg").Output()
	if err != nil {
		return err
	}
	if len(out) > 0 {
		log.Printf("Thumbnail: %s", string(out))
	}
	return nil
}
