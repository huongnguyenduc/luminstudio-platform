package search

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

type productSearcherStub struct {
	result ProductSearchResult
	err    error
	query  ProductSearchQuery
	calls  int
}

func (stub *productSearcherStub) SearchProducts(_ context.Context, query ProductSearchQuery) (ProductSearchResult, error) {
	stub.calls++
	stub.query = query
	return stub.result, stub.err
}

type catalogProductReaderStub struct {
	record product.ProductRecord
	err    error
	id     string
}

func (stub *catalogProductReaderStub) GetProduct(_ context.Context, id string) (product.ProductRecord, error) {
	stub.id = id
	return stub.record, stub.err
}

type spriteAssetStoreStub struct {
	body []byte
	ref  product.ObjectRef
	err  error
}

func (stub *spriteAssetStoreStub) GetSpriteAsset(_ context.Context, ref product.ObjectRef) (io.ReadCloser, error) {
	stub.ref = ref
	if stub.err != nil {
		return nil, stub.err
	}
	return io.NopCloser(bytes.NewReader(stub.body)), nil
}

func TestListCatalogProductsReturnsCustomerSafeItems(t *testing.T) {
	now := time.Date(2026, 6, 16, 9, 0, 0, 0, time.UTC)
	spriteSize := int64(4096)
	searcher := &productSearcherStub{result: ProductSearchResult{
		Total: 1,
		Hits: []ProductDocument{{
			ID:               "prod_12345678",
			Name:             "Arc Chair",
			Slug:             "arc-chair",
			Description:      "Configurable chair.",
			InformationText:  "admin index text",
			ProcessingStatus: product.ProcessingCompleted,
			SpriteAsset: &product.ObjectRef{
				Bucket:    "lumin-360-sprites",
				Key:       "prod_12345678_360_sprite.jpg",
				SizeBytes: &spriteSize,
			},
			UpdatedAt: now,
		}},
	}}
	handler := NewHandler(searcher)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/products?limit=12&offset=24", nil)

	handler.ListCatalogProducts(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
	if searcher.query != (ProductSearchQuery{Limit: 12, Offset: 24}) {
		t.Fatalf("query = %#v", searcher.query)
	}
	var got CatalogSearchResponse
	if err := json.Unmarshal(recorder.Body.Bytes(), &got); err != nil {
		t.Fatalf("decode catalog response: %v", err)
	}
	if got.Total != 1 || got.Limit != 12 || got.Offset != 24 || len(got.Items) != 1 {
		t.Fatalf("unexpected response: %#v", got)
	}
	if got.Items[0].SpriteAsset == nil || got.Items[0].SpriteAsset.Bucket != "lumin-360-sprites" {
		t.Fatalf("sprite asset missing from customer item: %#v", got.Items[0])
	}
	if strings.Contains(recorder.Body.String(), "informationText") {
		t.Fatalf("customer response leaked index-only text: %s", recorder.Body.String())
	}
}

func TestGetCatalogProductSpriteStreamsCompletedSprite(t *testing.T) {
	size := int64(3)
	reader := &catalogProductReaderStub{record: ProductRecordWithSprite(size)}
	store := &spriteAssetStoreStub{body: []byte{0xff, 0xd8, 0xff}}
	handler := NewHandler(&productSearcherStub{}).
		WithCatalogProductReader(reader).
		WithSpriteAssetStore(store)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/products/prod_12345678/sprite", nil)
	request.SetPathValue("id", "prod_12345678")

	handler.GetCatalogProductSprite(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
	if reader.id != "prod_12345678" {
		t.Fatalf("reader id = %q", reader.id)
	}
	if store.ref.Bucket != "lumin-360-sprites" || store.ref.Key != "prod_12345678_360_sprite.jpg" {
		t.Fatalf("store ref = %#v", store.ref)
	}
	if recorder.Header().Get("Content-Type") != "image/jpeg" {
		t.Fatalf("content-type = %q", recorder.Header().Get("Content-Type"))
	}
	if recorder.Header().Get("Content-Length") != "3" {
		t.Fatalf("content-length = %q", recorder.Header().Get("Content-Length"))
	}
	if !bytes.Equal(recorder.Body.Bytes(), []byte{0xff, 0xd8, 0xff}) {
		t.Fatalf("body = %v", recorder.Body.Bytes())
	}
}

func TestGetCatalogProductSpriteRejectsInvalidID(t *testing.T) {
	handler := NewHandler(&productSearcherStub{}).
		WithCatalogProductReader(&catalogProductReaderStub{}).
		WithSpriteAssetStore(&spriteAssetStoreStub{})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/products/bad/sprite", nil)
	request.SetPathValue("id", "bad")

	handler.GetCatalogProductSprite(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
}

func TestGetCatalogProductSpriteRequiresCompletedSprite(t *testing.T) {
	record := ProductRecordWithSprite(3)
	record.ProcessingStatus = product.ProcessingQueued
	handler := NewHandler(&productSearcherStub{}).
		WithCatalogProductReader(&catalogProductReaderStub{record: record}).
		WithSpriteAssetStore(&spriteAssetStoreStub{body: []byte("sprite")})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/products/prod_12345678/sprite", nil)
	request.SetPathValue("id", "prod_12345678")

	handler.GetCatalogProductSprite(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusNotFound)
	}
}

func TestGetCatalogProductSpriteReportsStorageFailure(t *testing.T) {
	handler := NewHandler(&productSearcherStub{}).
		WithCatalogProductReader(&catalogProductReaderStub{record: ProductRecordWithSprite(3)}).
		WithSpriteAssetStore(&spriteAssetStoreStub{err: errors.New("minio unavailable")})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/products/prod_12345678/sprite", nil)
	request.SetPathValue("id", "prod_12345678")

	handler.GetCatalogProductSprite(recorder, request)

	if recorder.Code != http.StatusBadGateway {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadGateway)
	}
}

func TestSearchCatalogProductsRequiresQuery(t *testing.T) {
	searcher := &productSearcherStub{}
	handler := NewHandler(searcher)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/search", nil)

	handler.SearchCatalogProducts(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
	if searcher.calls != 0 {
		t.Fatalf("searcher calls = %d, want 0", searcher.calls)
	}
}

func ProductRecordWithSprite(size int64) product.ProductRecord {
	now := time.Date(2026, 6, 16, 9, 0, 0, 0, time.UTC)
	return product.ProductRecord{
		ID:               "prod_12345678",
		Name:             "Arc Chair",
		Slug:             "arc-chair",
		Description:      "Configurable chair.",
		CreatedAt:        now,
		UpdatedAt:        now,
		ProcessingStatus: product.ProcessingCompleted,
		SpriteAsset: &product.ObjectRef{
			Bucket:      "lumin-360-sprites",
			Key:         "prod_12345678_360_sprite.jpg",
			ContentType: "image/jpeg",
			SizeBytes:   &size,
		},
	}
}

func TestSearchCatalogProductsValidatesLimit(t *testing.T) {
	handler := NewHandler(&productSearcherStub{})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/search?q=chair&limit=101", nil)

	handler.SearchCatalogProducts(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
}

func TestSearchCatalogProductsReportsBackendFailure(t *testing.T) {
	handler := NewHandler(&productSearcherStub{err: errors.New("search unavailable")})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/search?q=chair", nil)

	handler.SearchCatalogProducts(recorder, request)

	if recorder.Code != http.StatusBadGateway {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadGateway)
	}
}

func TestMeilisearchSearcherSearchesProducts(t *testing.T) {
	now := time.Date(2026, 6, 16, 9, 0, 0, 0, time.UTC)
	var method string
	var path string
	var authorization string
	var payload map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		method = request.Method
		path = request.URL.String()
		authorization = request.Header.Get("Authorization")
		if err := json.NewDecoder(request.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request body: %v", err)
		}
		_ = json.NewEncoder(response).Encode(map[string]any{
			"hits": []ProductDocument{{
				ID:               "prod_12345678",
				Name:             "Arc Chair",
				Slug:             "arc-chair",
				Description:      "Configurable chair.",
				ProcessingStatus: product.ProcessingCompleted,
				UpdatedAt:        now,
			}},
			"estimatedTotalHits": 3,
		})
	}))
	defer server.Close()
	baseURL, err := url.Parse(server.URL)
	if err != nil {
		t.Fatalf("parse test URL: %v", err)
	}
	searcher := NewMeilisearchSearcher(baseURL, "search-key", time.Second)

	result, err := searcher.SearchProducts(context.Background(), ProductSearchQuery{Query: "chaor", Limit: 10, Offset: 20})
	if err != nil {
		t.Fatalf("search products: %v", err)
	}

	if method != http.MethodPost {
		t.Fatalf("method = %q", method)
	}
	if path != "/indexes/products/search" {
		t.Fatalf("path = %q", path)
	}
	if authorization != "Bearer search-key" {
		t.Fatalf("authorization = %q", authorization)
	}
	if payload["q"] != "chaor" || payload["limit"] != float64(10) || payload["offset"] != float64(20) {
		t.Fatalf("payload = %#v", payload)
	}
	if result.Total != 3 || len(result.Hits) != 1 || result.Hits[0].ID != "prod_12345678" {
		t.Fatalf("result = %#v", result)
	}
}
