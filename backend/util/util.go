package util

import (
	"encoding/json"
	"fmt"
	"log"
	"mime"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"time"

	"github.com/teris-io/shortid"
)

var (
	DataPath string

	uid           *shortid.Shortid
	dateRegex     = regexp.MustCompile(`(\d{4})-(\d{2})-(\d{2})`)
	dateTimeRegex = regexp.MustCompile(`(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})`)

	DateFormat      = "2006-01-02"
	DateTimeFormat  = "2006-01-02 15:04:05"
	SDateTimeFormat = "2006-01-02T15:04:05.000Z"
)

func init() {
	DataPath = os.Getenv("DATA_PATH")
	if DataPath == "" {
		log.Printf("Set DATA_PATH env var to set the location of media storage")
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

func StringsToInt64(vals []string) []int64 {
	var newVals []int64
	for _, val := range vals {
		newVals = append(newVals, Atoi64(val))
	}
	return newVals
}

func Int64ToStrings(vals []int64) []string {
	var newVals []string
	for _, val := range vals {
		newVals = append(newVals, I64toa(val))
	}
	return newVals
}

func TimeFromPath(p string) time.Time {
	now := time.Now()
	m := dateTimeRegex.FindStringSubmatch(p)
	if len(m) > 0 {
		now, _ = time.Parse(DateTimeFormat, fmt.Sprintf("%s-%s-%s %s:%s:%s", m[1], m[2], m[3], m[4], m[5], m[6]))
		return now
	}
	m = dateRegex.FindStringSubmatch(p)
	if len(m) > 0 {
		now, _ = time.Parse(DateFormat, fmt.Sprintf("%s-%s-%s", m[1], m[2], m[3]))
		return now
	}
	fi, err := os.Stat(p)
	if err == nil {
		return fi.ModTime()
	}
	return now
}

func TypeByExt(ext string) string {
	if val, ok := MimeTypes[ext]; ok {
		return val
	}
	return mime.TypeByExtension(ext)
}
