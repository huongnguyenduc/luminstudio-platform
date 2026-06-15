package main

import (
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"time"

	"lumin.studio/services/api-gateway/internal/health"
)

const defaultPort = 8080

func main() {
	port, err := portFromEnv(os.Getenv("PORT"))
	if err != nil {
		slog.Error("invalid server configuration", "error", err)
		os.Exit(1)
	}

	server := &http.Server{
		Addr:              fmt.Sprintf(":%d", port),
		Handler:           routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	slog.Info("api gateway starting", "address", server.Addr)
	if err := server.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
		slog.Error("api gateway stopped", "error", err)
		os.Exit(1)
	}
}

func routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", health.Handler)
	return mux
}

func portFromEnv(value string) (int, error) {
	if value == "" {
		return defaultPort, nil
	}

	port, err := strconv.Atoi(value)
	if err != nil || port < 1 || port > 65535 {
		return 0, fmt.Errorf("PORT must be an integer from 1 to 65535")
	}
	return port, nil
}
