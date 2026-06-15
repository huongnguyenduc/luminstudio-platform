package platform

import (
	"fmt"
	"net/url"
	"time"
)

const defaultCheckTimeout = 2 * time.Second

type Config struct {
	DatabaseURL       string
	MinIOURL          *url.URL
	MinIOAccessKey    string
	MinIOSecretKey    string
	NATSURL           *url.URL
	MeilisearchURL    *url.URL
	MeilisearchKey    string
	DependencyTimeout time.Duration
}

func ConfigFromEnv(getenv func(string) string) (Config, error) {
	databaseURL := getenv("DATABASE_URL")
	if databaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}

	minioURL, err := requiredURL("MINIO_URL", getenv("MINIO_URL"), "http", "https")
	if err != nil {
		return Config{}, err
	}
	minioAccessKey := getenv("MINIO_ACCESS_KEY")
	if minioAccessKey == "" {
		return Config{}, fmt.Errorf("MINIO_ACCESS_KEY is required")
	}
	minioSecretKey := getenv("MINIO_SECRET_KEY")
	if minioSecretKey == "" {
		return Config{}, fmt.Errorf("MINIO_SECRET_KEY is required")
	}
	natsURL, err := requiredURL("NATS_URL", getenv("NATS_URL"), "nats")
	if err != nil {
		return Config{}, err
	}
	meilisearchURL, err := requiredURL("MEILISEARCH_URL", getenv("MEILISEARCH_URL"), "http", "https")
	if err != nil {
		return Config{}, err
	}

	meilisearchKey := getenv("MEILISEARCH_API_KEY")
	if meilisearchKey == "" {
		return Config{}, fmt.Errorf("MEILISEARCH_API_KEY is required")
	}

	timeout := defaultCheckTimeout
	if value := getenv("DEPENDENCY_CHECK_TIMEOUT"); value != "" {
		timeout, err = time.ParseDuration(value)
		if err != nil || timeout <= 0 {
			return Config{}, fmt.Errorf("DEPENDENCY_CHECK_TIMEOUT must be a positive duration")
		}
	}

	return Config{
		DatabaseURL:       databaseURL,
		MinIOURL:          minioURL,
		MinIOAccessKey:    minioAccessKey,
		MinIOSecretKey:    minioSecretKey,
		NATSURL:           natsURL,
		MeilisearchURL:    meilisearchURL,
		MeilisearchKey:    meilisearchKey,
		DependencyTimeout: timeout,
	}, nil
}

func requiredURL(name, value string, schemes ...string) (*url.URL, error) {
	if value == "" {
		return nil, fmt.Errorf("%s is required", name)
	}
	parsed, err := url.Parse(value)
	if err != nil || parsed.Host == "" {
		return nil, fmt.Errorf("%s must be an absolute URL", name)
	}
	for _, scheme := range schemes {
		if parsed.Scheme == scheme {
			return parsed, nil
		}
	}
	return nil, fmt.Errorf("%s uses unsupported scheme %q", name, parsed.Scheme)
}
