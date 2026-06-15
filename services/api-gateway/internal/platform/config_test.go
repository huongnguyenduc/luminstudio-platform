package platform

import (
	"testing"
	"time"
)

func TestConfigFromEnv(t *testing.T) {
	values := map[string]string{
		"DATABASE_URL":        "postgres://lumin:secret@postgres:5432/lumin",
		"MINIO_URL":           "http://minio:9000",
		"MINIO_ACCESS_KEY":    "access-key",
		"MINIO_SECRET_KEY":    "secret-key",
		"NATS_URL":            "nats://nats:4222",
		"MEILISEARCH_URL":     "http://meilisearch:7700",
		"MEILISEARCH_API_KEY": "development-key",
	}
	config, err := ConfigFromEnv(func(name string) string { return values[name] })
	if err != nil {
		t.Fatal(err)
	}
	if config.DependencyTimeout != defaultCheckTimeout {
		t.Fatalf("timeout = %s, want %s", config.DependencyTimeout, defaultCheckTimeout)
	}
}

func TestConfigFromEnvRejectsInvalidValues(t *testing.T) {
	base := map[string]string{
		"DATABASE_URL":        "postgres://lumin:secret@postgres:5432/lumin",
		"MINIO_URL":           "http://minio:9000",
		"MINIO_ACCESS_KEY":    "access-key",
		"MINIO_SECRET_KEY":    "secret-key",
		"NATS_URL":            "nats://nats:4222",
		"MEILISEARCH_URL":     "http://meilisearch:7700",
		"MEILISEARCH_API_KEY": "development-key",
	}
	tests := []struct {
		name  string
		key   string
		value string
	}{
		{name: "missing database", key: "DATABASE_URL"},
		{name: "invalid minio", key: "MINIO_URL", value: "minio:9000"},
		{name: "missing minio access key", key: "MINIO_ACCESS_KEY"},
		{name: "missing minio secret key", key: "MINIO_SECRET_KEY"},
		{name: "invalid nats scheme", key: "NATS_URL", value: "http://nats:4222"},
		{name: "missing search key", key: "MEILISEARCH_API_KEY"},
		{name: "invalid timeout", key: "DEPENDENCY_CHECK_TIMEOUT", value: "0s"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			values := make(map[string]string, len(base)+1)
			for key, value := range base {
				values[key] = value
			}
			values[test.key] = test.value
			if _, err := ConfigFromEnv(func(name string) string { return values[name] }); err == nil {
				t.Fatal("expected configuration error")
			}
		})
	}
}

func TestConfigFromEnvAcceptsConfiguredTimeout(t *testing.T) {
	values := map[string]string{
		"DATABASE_URL":             "postgres://lumin:secret@postgres:5432/lumin",
		"MINIO_URL":                "http://minio:9000",
		"MINIO_ACCESS_KEY":         "access-key",
		"MINIO_SECRET_KEY":         "secret-key",
		"NATS_URL":                 "nats://nats:4222",
		"MEILISEARCH_URL":          "http://meilisearch:7700",
		"MEILISEARCH_API_KEY":      "development-key",
		"DEPENDENCY_CHECK_TIMEOUT": "5s",
	}
	config, err := ConfigFromEnv(func(name string) string { return values[name] })
	if err != nil {
		t.Fatal(err)
	}
	if config.DependencyTimeout != 5*time.Second {
		t.Fatalf("timeout = %s, want 5s", config.DependencyTimeout)
	}
}
