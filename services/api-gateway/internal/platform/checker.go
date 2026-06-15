package platform

import (
	"bufio"
	"context"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

const natsConnect = "CONNECT {\"verbose\":false,\"pedantic\":true,\"lang\":\"go\",\"version\":\"lumin-api-gateway\"}\r\n"

type Checker struct {
	postgres       *pgxpool.Pool
	httpClient     *http.Client
	minio          *minio.Client
	natsURL        *url.URL
	meilisearchURL *url.URL
	meilisearchKey string
	timeout        time.Duration
}

func NewChecker(config Config) (*Checker, error) {
	poolConfig, err := pgxpool.ParseConfig(config.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse DATABASE_URL: %w", err)
	}
	pool, err := pgxpool.NewWithConfig(context.Background(), poolConfig)
	if err != nil {
		return nil, fmt.Errorf("create PostgreSQL pool: %w", err)
	}
	minioClient, err := minio.New(config.MinIOURL.Host, &minio.Options{
		Creds:  credentials.NewStaticV4(config.MinIOAccessKey, config.MinIOSecretKey, ""),
		Secure: config.MinIOURL.Scheme == "https",
	})
	if err != nil {
		pool.Close()
		return nil, fmt.Errorf("create MinIO client: %w", err)
	}

	return &Checker{
		postgres:       pool,
		httpClient:     &http.Client{Timeout: config.DependencyTimeout},
		minio:          minioClient,
		natsURL:        config.NATSURL,
		meilisearchURL: config.MeilisearchURL,
		meilisearchKey: config.MeilisearchKey,
		timeout:        config.DependencyTimeout,
	}, nil
}

func (checker *Checker) Close() {
	checker.postgres.Close()
}

func (checker *Checker) Postgres() *pgxpool.Pool {
	return checker.postgres
}

func (checker *Checker) MinIO() *minio.Client {
	return checker.minio
}

func (checker *Checker) Check(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, checker.timeout)
	defer cancel()

	checks := []struct {
		name  string
		check func(context.Context) error
	}{
		{name: "postgres", check: checker.checkPostgres},
		{name: "minio", check: checker.checkMinIO},
		{name: "nats", check: checker.checkNATS},
		{name: "meilisearch", check: checker.checkMeilisearch},
	}
	for _, dependency := range checks {
		if err := dependency.check(ctx); err != nil {
			return fmt.Errorf("%s: %w", dependency.name, err)
		}
	}
	return nil
}

func (checker *Checker) checkPostgres(ctx context.Context) error {
	return checker.postgres.Ping(ctx)
}

func (checker *Checker) checkMinIO(ctx context.Context) error {
	_, err := checker.minio.ListBuckets(ctx)
	return err
}

func (checker *Checker) checkMeilisearch(ctx context.Context) error {
	return checker.checkHTTP(ctx, checker.meilisearchURL, "/version", checker.meilisearchKey)
}

func (checker *Checker) checkHTTP(ctx context.Context, baseURL *url.URL, path, bearerToken string) error {
	target := *baseURL
	target.Path = strings.TrimRight(target.Path, "/") + path
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, target.String(), nil)
	if err != nil {
		return err
	}
	if bearerToken != "" {
		request.Header.Set("Authorization", "Bearer "+bearerToken)
	}
	response, err := checker.httpClient.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("HTTP status %d", response.StatusCode)
	}
	return nil
}

func (checker *Checker) checkNATS(ctx context.Context) error {
	dialer := net.Dialer{}
	connection, err := dialer.DialContext(ctx, "tcp", checker.natsURL.Host)
	if err != nil {
		return err
	}
	defer connection.Close()
	if deadline, ok := ctx.Deadline(); ok {
		_ = connection.SetDeadline(deadline)
	}

	reader := bufio.NewReader(connection)
	line, err := reader.ReadString('\n')
	if err != nil {
		return err
	}
	if !strings.HasPrefix(line, "INFO ") {
		return fmt.Errorf("unexpected server greeting")
	}
	if _, err := connection.Write([]byte(natsConnect + "PING\r\n")); err != nil {
		return err
	}
	line, err = reader.ReadString('\n')
	if err != nil {
		return err
	}
	if strings.TrimSpace(line) != "PONG" {
		return fmt.Errorf("unexpected PING response")
	}
	return nil
}
