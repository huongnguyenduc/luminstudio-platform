package search

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

type readerStub struct {
	record product.ProductRecord
	err    error
	id     string
}

func (stub *readerStub) GetProduct(_ context.Context, id string) (product.ProductRecord, error) {
	stub.id = id
	return stub.record, stub.err
}

type indexerStub struct {
	record product.ProductRecord
	err    error
	calls  int
}

func (stub *indexerStub) UpsertProduct(_ context.Context, record product.ProductRecord) error {
	stub.calls++
	stub.record = record
	return stub.err
}

func TestHandleProductUpdatedIndexesFetchedProduct(t *testing.T) {
	now := time.Date(2026, 6, 15, 14, 0, 0, 0, time.UTC)
	reader := &readerStub{record: validSearchRecord(now)}
	indexer := &indexerStub{}
	syncer := NewSyncer(reader, indexer)

	if err := syncer.HandleProductUpdated(context.Background(), productUpdatedJSON(t, now)); err != nil {
		t.Fatalf("handle product.updated: %v", err)
	}

	if reader.id != "prod_12345678" {
		t.Fatalf("reader id = %q", reader.id)
	}
	if indexer.calls != 1 || indexer.record.ID != "prod_12345678" {
		t.Fatalf("unexpected indexer call: %#v", indexer)
	}
}

func TestHandleProductUpdatedRejectsWrongEventType(t *testing.T) {
	now := time.Date(2026, 6, 15, 14, 0, 0, 0, time.UTC)
	event := product.ProductUpdatedEvent{
		ID:            "evt_12345678",
		Type:          "3d.task.created",
		SchemaVersion: "v1",
		OccurredAt:    now,
		CorrelationID: "corr_12345678",
		Payload: product.ProductUpdatedPayload{
			ProductID: "prod_12345678",
			ChangedAt: now,
		},
	}
	data, err := json.Marshal(event)
	if err != nil {
		t.Fatalf("marshal event: %v", err)
	}

	if err := NewSyncer(&readerStub{}, &indexerStub{}).HandleProductUpdated(context.Background(), data); err == nil {
		t.Fatal("wrong event type must fail")
	}
}

func TestHandleProductUpdatedPropagatesReaderFailure(t *testing.T) {
	now := time.Date(2026, 6, 15, 14, 0, 0, 0, time.UTC)
	reader := &readerStub{err: errors.New("database unavailable")}
	indexer := &indexerStub{}

	err := NewSyncer(reader, indexer).HandleProductUpdated(context.Background(), productUpdatedJSON(t, now))

	if err == nil || !strings.Contains(err.Error(), "read product for search sync") {
		t.Fatalf("error = %v", err)
	}
	if indexer.calls != 0 {
		t.Fatalf("indexer calls = %d, want 0", indexer.calls)
	}
}

func TestMeilisearchIndexerUpsertsProductDocument(t *testing.T) {
	now := time.Date(2026, 6, 15, 14, 0, 0, 0, time.UTC)
	var paths []string
	var authorization string
	var indexRequest map[string]string
	var documents []ProductDocument
	var settings map[string][]string
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		paths = append(paths, request.Method+" "+request.URL.String())
		authorization = request.Header.Get("Authorization")
		switch {
		case request.Method == http.MethodGet && request.URL.Path == "/indexes/products":
			response.WriteHeader(http.StatusNotFound)
		case request.Method == http.MethodPost && request.URL.Path == "/indexes":
			if err := json.NewDecoder(request.Body).Decode(&indexRequest); err != nil {
				t.Fatalf("decode index body: %v", err)
			}
			response.WriteHeader(http.StatusAccepted)
		case request.Method == http.MethodPatch:
			if err := json.NewDecoder(request.Body).Decode(&settings); err != nil {
				t.Fatalf("decode settings body: %v", err)
			}
			response.WriteHeader(http.StatusAccepted)
		case request.Method == http.MethodPost:
			if err := json.NewDecoder(request.Body).Decode(&documents); err != nil {
				t.Fatalf("decode request body: %v", err)
			}
			response.WriteHeader(http.StatusAccepted)
		default:
			t.Fatalf("unexpected method %s", request.Method)
		}
	}))
	defer server.Close()
	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatalf("parse test URL: %v", err)
	}

	indexer := NewMeilisearchIndexer(baseURL, "search-key", time.Second)
	if err := indexer.UpsertProduct(context.Background(), validSearchRecord(now)); err != nil {
		t.Fatalf("upsert product: %v", err)
	}

	if len(paths) != 4 ||
		paths[0] != "GET /indexes/products" ||
		paths[1] != "POST /indexes" ||
		paths[2] != "PATCH /indexes/products/settings" ||
		paths[3] != "POST /indexes/products/documents?primaryKey=id" {
		t.Fatalf("paths = %#v", paths)
	}
	if indexRequest["uid"] != "products" || indexRequest["primaryKey"] != "id" {
		t.Fatalf("index request = %#v", indexRequest)
	}
	if authorization != "Bearer search-key" {
		t.Fatalf("authorization = %q", authorization)
	}
	if len(settings["filterableAttributes"]) != 2 ||
		settings["filterableAttributes"][0] != "categorySlugs" ||
		settings["filterableAttributes"][1] != "categoryKeys" {
		t.Fatalf("settings = %#v", settings)
	}
	if len(documents) != 1 ||
		documents[0].ID != "prod_12345678" ||
		documents[0].InformationText == "" ||
		documents[0].Price.AmountCents != 12900 ||
		documents[0].PriceAmountCents != 12900 ||
		len(documents[0].CategorySlugs) != 1 ||
		documents[0].CategorySlugs[0] != "chairs" ||
		len(documents[0].CategoryKeys) != 1 ||
		documents[0].CategoryKeys[0] != "chairs\tChairs" {
		t.Fatalf("documents = %#v", documents)
	}
}

func productUpdatedJSON(t *testing.T, now time.Time) []byte {
	t.Helper()
	event := product.ProductUpdatedEvent{
		ID:            "evt_12345678",
		Type:          "product.updated",
		SchemaVersion: "v1",
		OccurredAt:    now,
		CorrelationID: "corr_12345678",
		Payload: product.ProductUpdatedPayload{
			ProductID: "prod_12345678",
			ChangedAt: now,
		},
	}
	data, err := json.Marshal(event)
	if err != nil {
		t.Fatalf("marshal event: %v", err)
	}
	return data
}

func validSearchRecord(now time.Time) product.ProductRecord {
	return product.ProductRecord{
		ID:          "prod_12345678",
		Name:        "Arc Chair",
		Slug:        "arc-chair",
		Description: "Configurable chair.",
		Price:       product.ProductPrice{AmountCents: 12900, Currency: "USD"},
		Categories:  []product.ProductCategory{{Slug: "chairs", Name: "Chairs"}},
		InformationSections: []product.InformationSection{
			{Title: "Materials", Body: "Oak and wool."},
		},
		CreatedAt:        now,
		UpdatedAt:        now,
		ProcessingStatus: product.ProcessingNotStarted,
	}
}
