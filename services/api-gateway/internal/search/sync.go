package search

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

const (
	productIndexUID = "products"
	natsQueueGroup  = "search-sync"
	natsSID         = "1"
)

type ProductReader interface {
	GetProduct(ctx context.Context, id string) (product.ProductRecord, error)
}

type ProductIndexer interface {
	UpsertProduct(ctx context.Context, record product.ProductRecord) error
}

type Syncer struct {
	reader  ProductReader
	indexer ProductIndexer
}

func NewSyncer(reader ProductReader, indexer ProductIndexer) Syncer {
	return Syncer{reader: reader, indexer: indexer}
}

func (syncer Syncer) HandleProductUpdated(ctx context.Context, data []byte) error {
	if syncer.reader == nil {
		return errors.New("product reader is not configured")
	}
	if syncer.indexer == nil {
		return errors.New("product indexer is not configured")
	}

	var event product.ProductUpdatedEvent
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&event); err != nil {
		return fmt.Errorf("decode product.updated event: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		return errors.New("product.updated event must contain one JSON object")
	}
	if event.Type != "product.updated" || event.SchemaVersion != "v1" {
		return errors.New("event must be a v1 product.updated envelope")
	}
	if event.Payload.ProductID == "" || event.Payload.ChangedAt.IsZero() || event.CorrelationID == "" {
		return errors.New("product.updated event is missing required v1 fields")
	}

	record, err := syncer.reader.GetProduct(ctx, event.Payload.ProductID)
	if err != nil {
		return fmt.Errorf("read product for search sync: %w", err)
	}
	if record.ID != event.Payload.ProductID {
		return errors.New("product.updated event product id does not match fetched record")
	}
	return syncer.indexer.UpsertProduct(ctx, record)
}

type MeilisearchIndexer struct {
	baseURL    *url.URL
	apiKey     string
	httpClient *http.Client
}

func NewMeilisearchIndexer(baseURL *url.URL, apiKey string, timeout time.Duration) MeilisearchIndexer {
	return MeilisearchIndexer{
		baseURL: baseURL,
		apiKey:  apiKey,
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}
}

type ProductDocument struct {
	ID               string                   `json:"id"`
	Name             string                   `json:"name"`
	Slug             string                   `json:"slug"`
	Description      string                   `json:"description"`
	InformationText  string                   `json:"informationText,omitempty"`
	ProcessingStatus product.ProcessingStatus `json:"processingStatus"`
	UpdatedAt        time.Time                `json:"updatedAt"`
}

func NewProductDocument(record product.ProductRecord) ProductDocument {
	sectionBodies := make([]string, 0, len(record.InformationSections))
	for _, section := range record.InformationSections {
		sectionBodies = append(sectionBodies, section.Title, section.Body)
	}
	return ProductDocument{
		ID:               record.ID,
		Name:             record.Name,
		Slug:             record.Slug,
		Description:      record.Description,
		InformationText:  strings.Join(sectionBodies, "\n"),
		ProcessingStatus: record.ProcessingStatus,
		UpdatedAt:        record.UpdatedAt,
	}
}

func (indexer MeilisearchIndexer) UpsertProduct(ctx context.Context, record product.ProductRecord) error {
	if indexer.baseURL == nil || indexer.baseURL.Host == "" {
		return errors.New("Meilisearch URL is not configured")
	}
	if indexer.apiKey == "" {
		return errors.New("Meilisearch API key is not configured")
	}
	payload, err := json.Marshal([]ProductDocument{NewProductDocument(record)})
	if err != nil {
		return fmt.Errorf("marshal product search document: %w", err)
	}

	target := *indexer.baseURL
	target.Path = strings.TrimRight(target.Path, "/") + "/indexes/" + productIndexUID + "/documents"
	query := target.Query()
	query.Set("primaryKey", "id")
	target.RawQuery = query.Encode()

	request, err := http.NewRequestWithContext(ctx, http.MethodPost, target.String(), bytes.NewReader(payload))
	if err != nil {
		return err
	}
	request.Header.Set("Authorization", "Bearer "+indexer.apiKey)
	request.Header.Set("Content-Type", "application/json")

	response, err := indexer.httpClient.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 1024))
		return fmt.Errorf("Meilisearch returned HTTP %d: %s", response.StatusCode, strings.TrimSpace(string(body)))
	}
	return nil
}

type EventHandler interface {
	HandleProductUpdated(ctx context.Context, data []byte) error
}

type NATSSubscriber struct {
	natsURL       *url.URL
	subject       string
	queueGroup    string
	sid           string
	timeout       time.Duration
	retryInterval time.Duration
	handler       EventHandler
}

func NewNATSSubscriber(natsURL *url.URL, timeout time.Duration, handler EventHandler) NATSSubscriber {
	return NATSSubscriber{
		natsURL:       natsURL,
		subject:       product.ProductUpdatedSubject,
		queueGroup:    natsQueueGroup,
		sid:           natsSID,
		timeout:       timeout,
		retryInterval: timeout,
		handler:       handler,
	}
}

func (subscriber NATSSubscriber) Run(ctx context.Context) error {
	if subscriber.natsURL == nil || subscriber.natsURL.Host == "" {
		return errors.New("NATS URL is not configured")
	}
	if subscriber.handler == nil {
		return errors.New("event handler is not configured")
	}
	if subscriber.retryInterval <= 0 {
		subscriber.retryInterval = time.Second
	}

	for {
		if err := subscriber.runOnce(ctx); err != nil && ctx.Err() == nil {
			slog.Error("product search sync disconnected", "error", err)
		}
		if ctx.Err() != nil {
			return ctx.Err()
		}
		timer := time.NewTimer(subscriber.retryInterval)
		select {
		case <-ctx.Done():
			timer.Stop()
			return ctx.Err()
		case <-timer.C:
		}
	}
}

func (subscriber NATSSubscriber) runOnce(ctx context.Context) error {
	dialer := net.Dialer{}
	connection, err := dialer.DialContext(ctx, "tcp", subscriber.natsURL.Host)
	if err != nil {
		return fmt.Errorf("connect to NATS: %w", err)
	}
	defer connection.Close()
	if subscriber.timeout > 0 {
		_ = connection.SetDeadline(time.Now().Add(subscriber.timeout))
		defer connection.SetDeadline(time.Time{})
	}

	reader := io.Reader(connection)
	buffered := newNATSReader(reader)
	line, err := buffered.readLine()
	if err != nil {
		return fmt.Errorf("read NATS greeting: %w", err)
	}
	if !strings.HasPrefix(line, "INFO ") {
		return errors.New("unexpected NATS greeting")
	}
	if _, err := fmt.Fprintf(connection, "SUB %s %s %s\r\nPING\r\n", subscriber.subject, subscriber.queueGroup, subscriber.sid); err != nil {
		return fmt.Errorf("subscribe to product.updated: %w", err)
	}

	for {
		line, err := buffered.readLine()
		if err != nil {
			return err
		}
		fields := strings.Fields(line)
		if len(fields) == 0 {
			continue
		}
		switch fields[0] {
		case "PING":
			if _, err := connection.Write([]byte("PONG\r\n")); err != nil {
				return err
			}
		case "PONG":
			if subscriber.timeout > 0 {
				_ = connection.SetDeadline(time.Time{})
			}
		case "MSG":
			payload, err := buffered.readMessage(fields)
			if err != nil {
				return err
			}
			if err := subscriber.handler.HandleProductUpdated(ctx, payload); err != nil {
				slog.Error("product search sync failed", "error", err)
			}
		case "-ERR":
			return fmt.Errorf("NATS error: %s", line)
		}
	}
}

type natsReader struct {
	reader *strings.Reader
	source io.Reader
}

func newNATSReader(source io.Reader) natsReader {
	return natsReader{source: source}
}

func (reader natsReader) readLine() (string, error) {
	var builder strings.Builder
	var one [1]byte
	for {
		n, err := reader.source.Read(one[:])
		if n > 0 {
			builder.WriteByte(one[0])
			if strings.HasSuffix(builder.String(), "\r\n") {
				return strings.TrimSuffix(builder.String(), "\r\n"), nil
			}
		}
		if err != nil {
			return "", err
		}
	}
}

func (reader natsReader) readMessage(fields []string) ([]byte, error) {
	if len(fields) < 4 {
		return nil, errors.New("malformed NATS MSG line")
	}
	size, err := strconv.Atoi(fields[len(fields)-1])
	if err != nil || size < 0 {
		return nil, errors.New("malformed NATS MSG size")
	}
	payload := make([]byte, size+2)
	if _, err := io.ReadFull(reader.source, payload); err != nil {
		return nil, err
	}
	if string(payload[size:]) != "\r\n" {
		return nil, errors.New("malformed NATS MSG payload terminator")
	}
	return payload[:size], nil
}
