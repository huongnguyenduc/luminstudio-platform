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
	"lumin.studio/services/api-gateway/internal/platform"
	"lumin.studio/services/api-gateway/internal/product"
)

const defaultPort = 8080

func main() {
	if err := run(os.Getenv); err != nil {
		slog.Error("api gateway stopped", "error", err)
		os.Exit(1)
	}
}

func run(getenv func(string) string) error {
	port, err := portFromEnv(getenv("PORT"))
	if err != nil {
		return fmt.Errorf("invalid server configuration: %w", err)
	}

	config, err := platform.ConfigFromEnv(getenv)
	if err != nil {
		return fmt.Errorf("invalid platform configuration: %w", err)
	}
	checker, err := platform.NewChecker(config)
	if err != nil {
		return fmt.Errorf("initialize platform connectivity: %w", err)
	}
	defer checker.Close()

	server := &http.Server{
		Addr:              fmt.Sprintf(":%d", port),
		Handler:           routes(checker, product.NewHandler(product.NewStore(checker.Postgres()))),
		ReadHeaderTimeout: 5 * time.Second,
	}

	slog.Info("api gateway starting", "address", server.Addr)
	if err := server.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}

func routes(readiness health.Readiness, productHandler product.Handler) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", health.Handler)
	mux.Handle("GET /readyz", health.ReadinessHandler(readiness))
	mux.HandleFunc("POST /admin/products", productHandler.CreateProduct)
	mux.HandleFunc("GET /admin/products", productHandler.ListProducts)
	mux.HandleFunc("GET /admin/products/{id}", productHandler.GetProduct)
	mux.HandleFunc("PUT /admin/products/{id}", productHandler.UpdateProduct)
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
