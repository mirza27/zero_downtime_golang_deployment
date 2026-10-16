package main

import (
	"log"

	"technical-test-simple-server/internal/config"
	"technical-test-simple-server/internal/server"
)

var version = "dev"

func main() {
	cfg := config.Load()
	srv := server.New(cfg.Port, version)

	if err := srv.Start(); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}
