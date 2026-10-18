package server

import (
	"fmt"
	"net/http"
)

type Server struct {
	port    string
	version string
	mux     *http.ServeMux
}

func New(port, version string) *Server {
	s := &Server{
		port:    port,
		version: version,
		mux:     http.NewServeMux(),
	}
	s.routes()
	return s
}

func (s *Server) routes() {
	s.mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello this is failed, DevOps! version=%s\n", s.version)
	})
}

func (s *Server) Handler() http.Handler {
	return s.mux
}

func (s *Server) Start() error {
	fmt.Println("listening on :" + s.port)
	return http.ListenAndServe(":"+s.port, s.mux)
}
