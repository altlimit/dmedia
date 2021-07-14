package util

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

var (
	DataPath   string
	ffmpegBin  string
	ffprobeBin string
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
	ffprobeBin = os.Getenv("FFPROBE_BIN")
	if ffprobeBin == "" {
		panic(fmt.Errorf("FFPROBE_BIN set path of ffprobe binary"))
	}
}

func FileExists(path string) bool {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return false
	}
	return true
}

func Thumbnail(input string) error {
	out, err := exec.Command(ffmpegBin, "-i", input, "-ss", "00:00:01.000", "-vframes", "1", input+".jpg").Output()
	if err != nil {
		return err
	}
	if len(out) > 0 {
		log.Printf("Thumbnail: %s", string(out))
	}
	return nil
}

func VideoInfo(input string) string {
	out, err := exec.Command(ffprobeBin, "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", input).Output()
	if err != nil {
		log.Printf("VideoInfo: Error %v", err)
		return ""
	}
	if len(out) > 0 {
		return string(out)
	}
	return ""
}
