package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"time"

	"lumin.studio/services/api-gateway/internal/health"
	"lumin.studio/services/api-gateway/internal/platform"
	"lumin.studio/services/api-gateway/internal/processing"
	"lumin.studio/services/api-gateway/internal/product"
	"lumin.studio/services/api-gateway/internal/search"
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

	productStore := product.NewStore(checker.Postgres())
	searchSyncer := search.NewSyncer(
		productStore,
		search.NewMeilisearchIndexer(config.MeilisearchURL, config.MeilisearchKey, config.DependencyTimeout),
	)
	go func() {
		err := search.NewNATSSubscriber(config.NATSURL, config.DependencyTimeout, searchSyncer).Run(context.Background())
		if err != nil && !errors.Is(err, context.Canceled) {
			slog.Error("product search sync stopped", "error", err)
		}
	}()
	completionHandler := processing.NewCompletionHandler(productStore)
	go func() {
		err := processing.NewNATSSubscriber(config.NATSURL, config.DependencyTimeout, completionHandler).Run(context.Background())
		if err != nil && !errors.Is(err, context.Canceled) {
			slog.Error("processing completion subscriber stopped", "error", err)
		}
	}()

	server := &http.Server{
		Addr: fmt.Sprintf(":%d", port),
		Handler: routes(
			checker,
			product.NewHandler(productStore).
				WithSourceAssetStore(product.NewMinIOSourceAssetStore(checker.MinIO())).
				WithEventPublisher(product.NewNATSPublisher(config.NATSURL, config.DependencyTimeout)),
		),
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
	mux.HandleFunc("POST /admin/products/{id}/source-glb", productHandler.UploadProductSource)
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
