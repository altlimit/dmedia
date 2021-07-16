package util

import (
	"encoding/json"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"

	"github.com/teris-io/shortid"
)

var (
	DataPath string
	uid      *shortid.Shortid
)

func init() {
	DataPath = os.Getenv("DATA_PATH")
	if DataPath == "" {
		DataPath = filepath.Join("..", "data")
	}

	sid, err := shortid.New(1, shortid.DefaultABC, 2342)
	if err != nil {
		panic(err)
	}
	uid = sid
}

func NewID() string {
	return uid.MustGenerate()
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

// I64toa converts string to int64
func Atoi64(n string) int64 {
	num, _ := strconv.ParseInt(n, 10, 64)
	return num
}

// I64toa converts int64 to string
func I64toa(n int64) string {
	return strconv.FormatInt(n, 10)
}
