package sync

import (
	"bytes"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"mime/multipart"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"

	"github.com/tidwall/gjson"
)

type Telegram struct {
	Token   string `json:"token"`
	Channel string `json:"channel"`
}

func (t *Telegram) Valid() bool {
	if t.Token != "" && t.Channel != "" {
		resp, err := http.Get(t.getURL("getMe"))
		if err != nil {
			log.Println("valid error", err)
			return false
		}
		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			log.Println("valid read body error", err)
		}
		json := string(body)
		ok := gjson.Get(json, "ok")
		return ok.Bool()
	}
	return false
}

func (t *Telegram) getURL(method string) string {
	return fmt.Sprintf("https://api.telegram.org/bot%s/%s", t.Token, method)
}

func (t *Telegram) Upload(cType string, path string) (string, error) {
	form := map[string]string{"chat_id": t.Channel}
	var (
		field  string
		method string
	)
	if strings.HasPrefix(cType, "video/") {
		field = "video"
		method = "sendVideo"
	} else if strings.HasPrefix(cType, "image/") {
		field = "photo"
		method = "sendPhoto"
	} else {
		return "", fmt.Errorf("SendMedia not support")
	}
	form[field] = "@" + path
	ct, data, err := t.createForm(form)
	if err != nil {
		return "", fmt.Errorf("SendMedia form error %v", err)
	}
	resp, err := http.Post(t.getURL(method), ct, data)
	if err != nil {
		return "", fmt.Errorf("SendMedia post error %v", err)
	}
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("SendMedia response error %v", err)
	}
	json := string(body)
	ok := gjson.Get(json, "ok")
	if ok.Bool() {
		msgID := gjson.Get(json, "result.message_id")
		return strconv.FormatInt(msgID.Int(), 10), nil
	}
	errCode := gjson.Get(json, "error_code")
	errDesc := gjson.Get(json, "error_description")
	return "", fmt.Errorf("SendMedia error %d %s", errCode.Int(), errDesc.String())
}

func (t *Telegram) Delete(meta string) error {
	resp, err := http.PostForm(t.getURL("deleteMessage"), url.Values{
		"chat_id":    {t.Channel},
		"message_id": {meta},
	})
	if err != nil {
		return fmt.Errorf("DeleteMessage post error %v", err)
	}
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("DeleteMessage response error %v", err)
	}
	json := string(body)
	ok := gjson.Get(json, "ok")
	if ok.Bool() {
		return nil
	}
	errCode := gjson.Get(json, "error_code")
	errDesc := gjson.Get(json, "description")
	if strings.Contains(errDesc.String(), "message to delete not found") {
		return nil
	}
	return fmt.Errorf("DeleteMessage error %d %s", errCode.Int(), errDesc.String())
}

func (t *Telegram) createForm(form map[string]string) (string, io.Reader, error) {
	body := new(bytes.Buffer)
	mp := multipart.NewWriter(body)
	defer mp.Close()
	for key, val := range form {
		if strings.HasPrefix(val, "@") {
			val = val[1:]
			file, err := os.Open(val)
			if err != nil {
				return "", nil, err
			}
			defer file.Close()
			part, err := mp.CreateFormFile(key, val)
			if err != nil {
				return "", nil, err
			}
			io.Copy(part, file)
		} else {
			mp.WriteField(key, val)
		}
	}
	return mp.FormDataContentType(), body, nil
}
