package util

import (
	"encoding/json"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

var (
	DataPath string
)

func init() {
	DataPath = os.Getenv("DATA_PATH")
	if DataPath == "" {
		DataPath = filepath.Join("..", "data")
	}
}

func FileExists(path string) bool {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return false
	}
	return true
}

func Thumbnail(input string) error {
	out, err := exec.Command("ffmpeg", "-i", input, "-ss", "00:00:01.000", "-vframes", "1", input+".jpg").Output()
	if err != nil {
		return err
	}
	if len(out) > 0 {
		log.Printf("Thumbnail: %s", string(out))
	}
	return nil
}

func VideoInfo(input string) map[string]interface{} {
	out, err := exec.Command("ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", input).Output()
	if err != nil {
		log.Printf("VideoInfo: Error %v", err)
		return nil
	}
	if len(out) > 0 {
		info := make(map[string]interface{})
		if err := json.Unmarshal(out, &info); err != nil {
			log.Printf("VideoInfo: UnmarshalError %v", err)
			return nil
		}
		return info
	}
	return nil
}
