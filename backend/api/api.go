package api

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"reflect"
	"regexp"
	"strings"
	"time"

	"github.com/altlimit/dmedia/model"
	"github.com/go-playground/validator/v10"
	"github.com/gorilla/handlers"
	"github.com/gorilla/mux"
)

const (
	KeyUser ctxKey = "user"
)

// Server defines how api request is handled
type (
	ctxKey string
	Server struct {
		router   *mux.Router
		validate *validator.Validate
	}

	validationError struct {
		Params map[string]string `json:"params"`
	}

	alertError struct {
		Title   string `json:"title"`
		Message string `json:"message"`
	}

	listResponse struct {
		Result interface{} `json:"result"`
		Pages  int         `json:"pages"`
	}
)

var (
	errAuth = fmt.Errorf("not logged in")
)

// Error validation error
func (ve validationError) Error() string {
	return fmt.Sprintf("Validation Error: %v", ve.Params)
}

// Error validation error
func (ae alertError) Error() string {
	return fmt.Sprintf("Alert Error: %s - %s", ae.Title, ae.Message)
}

// NewServer returns the instance of api server that implements the Handler interface
func NewServer() *Server {
	r := mux.NewRouter()

	srv := &Server{
		router:   r,
		validate: validator.New(),
	}
	// register function to get tag name from json tags.
	srv.validate.RegisterTagNameFunc(func(fld reflect.StructField) string {
		name := strings.SplitN(fld.Tag.Get("json"), ",", 2)[0]
		if name == "-" {
			return ""
		}
		return name
	})
	validUsername := regexp.MustCompile(`^[A-Za-z][A-Za-z0-9-_]{3,25}$`)
	// register function to get tag name from json tags.
	srv.validate.RegisterTagNameFunc(func(fld reflect.StructField) string {
		name := strings.SplitN(fld.Tag.Get("json"), ",", 2)[0]
		if name == "-" {
			return ""
		}
		return name
	})
	srv.validate.RegisterValidation("username", func(fl validator.FieldLevel) bool {
		return validUsername.Match([]byte(fl.Field().String()))
	})

	r.Use(handlers.CORS(
		handlers.AllowedHeaders([]string{"Accept", "Accept-Language", "Content-Type", "Content-Language", "Origin", "Authorization"}),
		handlers.AllowedMethods([]string{"GET", "HEAD", "POST", "DELETE", "PATCH", "PUT", "OPTIONS"}),
		handlers.AllowedOrigins([]string{"*"}),
		handlers.AllowCredentials(),
	))
	sr := r.PathPrefix("/api").Subrouter()
	sr.Use(srv.auth)

	sr.HandleFunc("/users", srv.handleCreateUser()).Methods(http.MethodPost)
	sr.HandleFunc("/users", srv.handleGetUser()).Methods(http.MethodGet)

	sr.HandleFunc("/upload", srv.handleUpload()).Methods(http.MethodPost)

	return srv
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	st := time.Now().UTC()
	log.Printf("%s %s", r.Method, r.URL.Path)
	s.router.ServeHTTP(w, r)
	if tt := time.Since(st).Milliseconds(); tt > 1000 {
		log.Printf("[SLOW] warning request: %s %s took %d ms", r.Method, r.RequestURI, tt)
	}
}

func (s *Server) handler(f func(r *http.Request) interface{}) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		result := f(r)
		if result != nil {
			if err, ok := result.(error); ok {
				s.writeError(w, err)
				return
			}
		}
		s.writeJSON(w, result)
	}
}

func (s *Server) writeError(w http.ResponseWriter, err error) bool {
	if err == nil {
		return false
	}
	var msg string
	code := http.StatusInternalServerError

	if errMsg := err.Error(); errMsg != "" {
		if strings.Contains(errMsg, "http: request body too large") {
			code = http.StatusRequestEntityTooLarge
		} else if strings.Contains(errMsg, "JSON input") {
			code = http.StatusBadRequest
		}
	}
	resp := map[string]interface{}{}

	if e, ok := err.(validationError); ok {
		code = http.StatusBadRequest
		msg = "validation"
		resp["params"] = e.Params
	} else if e, ok := err.(alertError); ok {
		code = http.StatusBadRequest
		msg = e.Message
		resp["title"] = e.Title
	} else if _, ok := err.(*json.UnmarshalTypeError); ok {
		log.Printf("UnmarshalTypeError: %v", err)
		code = http.StatusBadRequest
	} else if _, ok := err.(*json.SyntaxError); ok {
		log.Printf("JsonSyntaxError: %v", err)
		code = http.StatusBadRequest
	} else if err == errAuth {
		code = http.StatusUnauthorized
	} else {
		log.Printf("InternalError: %v", err)
	}

	if msg == "" && code > 0 {
		msg = http.StatusText(code)
	}
	resp["error"] = msg
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		panic(err)
	}
	return true
}

func (s *Server) writeJSON(w http.ResponseWriter, resp interface{}) {
	if resp == nil {
		w.WriteHeader(http.StatusOK)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		panic(err)
	}
}

func (s *Server) readJSON(r *http.Request, out interface{}) error {
	body, err := ioutil.ReadAll(io.LimitReader(r.Body, 1048576))
	if err != nil {
		return err
	}
	if err := r.Body.Close(); err != nil {
		return err
	}
	if err := json.Unmarshal(body, out); err != nil {
		return err
	}
	return nil
}

func (s *Server) bind(r *http.Request, out interface{}) error {
	if err := s.readJSON(r, out); err != nil {
		return err
	}
	if err := s.validationError(out); err != nil {
		return err
	}
	return nil
}

func (s *Server) validationError(src interface{}) error {
	err := s.validate.Struct(src)
	if err != nil {
		vr := validationError{Params: make(map[string]string)}
		for _, err := range err.(validator.ValidationErrors) {
			ss := strings.Split(err.Namespace(), ".")
			ss = ss[1:]
			vr.Params[strings.Join(ss, ".")] = err.Tag()
		}
		return vr
	}
	return nil
}

func (s *Server) writeOut(w http.ResponseWriter, code int, cType string, out []byte) {
	w.WriteHeader(code)
	w.Header().Set("Content-Type", cType)
	w.Write(out)
}

func (s *Server) cursor(list interface{}, pages int) interface{} {
	return listResponse{Result: list, Pages: pages}
}

func (s *Server) auth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user, pass, ok := r.BasicAuth()
		if !ok {
			log.Println("basic auth not provided")
			s.writeError(w, errAuth)
			return
		} else {
			u, err := model.GetUser(user)
			if err != nil {
				s.writeError(w, err)
				return
			}
			if !u.ValidPassword(pass) {
				log.Println("invalid password")
				s.writeError(w, newValidationErr("password", "invalid"))
				return
			}
			ctx := r.Context()
			ctx = context.WithValue(ctx, KeyUser, u.Name)
			r = r.WithContext(ctx)
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) user(ctx context.Context) string {
	if user, ok := ctx.Value(KeyUser).(string); ok {
		return user
	}
	return ""
}

// QueryParam returns query parameter by name
func (s *Server) QueryParam(r *http.Request, name string) string {
	if v, ok := r.URL.Query()[name]; ok && len(v) > 0 {
		return v[0]
	}
	return ""
}

func newValidationErr(params ...string) validationError {
	p := make(map[string]string)
	for i := 0; i < len(params); i += 2 {
		if i+1 < len(params) {
			p[params[i]] = params[i+1]
		}
	}
	return validationError{Params: p}
}
