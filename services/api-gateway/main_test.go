package main

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
	"lumin.studio/services/api-gateway/internal/search"
)

type readyStub struct {
	err error
}

func (stub readyStub) Check(context.Context) error {
	return stub.err
}

type productCreatorStub struct{}

func (productCreatorStub) InsertProduct(_ context.Context, _ string, _ product.ProductDraft, now time.Time) (product.ProductRecord, error) {
	return routeProductRecord(now), nil
}

func (productCreatorStub) UpdateProduct(_ context.Context, _ string, _ product.ProductDraft, now time.Time) (product.ProductRecord, error) {
	return routeProductRecord(now), nil
}

func (productCreatorStub) GetProduct(_ context.Context, _ string) (product.ProductRecord, error) {
	return routeProductRecord(time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC)), nil
}

func (productCreatorStub) ListProducts(_ context.Context) ([]product.ProductRecord, error) {
	return []product.ProductRecord{routeProductRecord(time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC))}, nil
}

func (productCreatorStub) QueueSourceAsset(_ context.Context, _ string, sourceAsset product.ObjectRef, now time.Time) (product.ProductRecord, error) {
	record := routeProductRecord(now)
	record.SourceAsset = &sourceAsset
	record.ProcessingStatus = product.ProcessingQueued
	return record, nil
}

func routeProductRecord(now time.Time) product.ProductRecord {
	return product.ProductRecord{
		ID:               "prod_12345678",
		Name:             "Arc Chair",
		Slug:             "arc-chair",
		Description:      "Configurable chair.",
		MeshColorConfig:  product.MeshColorConfig{"mesh_body": {Default: "#FFFFFF", Allowed: []string{"#FFFFFF"}}},
		CreatedAt:        now,
		UpdatedAt:        now,
		ProcessingStatus: product.ProcessingNotStarted,
	}
}

type productSearcherRouteStub struct{}

func (productSearcherRouteStub) SearchProducts(_ context.Context, query search.ProductSearchQuery) (search.ProductSearchResult, error) {
	return search.ProductSearchResult{
		Total: 1,
		Hits: []search.ProductDocument{{
			ID:               "prod_12345678",
			Name:             "Arc Chair",
			Slug:             "arc-chair",
			Description:      "Configurable chair.",
			ProcessingStatus: product.ProcessingCompleted,
			UpdatedAt:        time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC),
		}},
	}, nil
}

func testRoutes() http.Handler {
	return routes(
		readyStub{},
		product.NewHandler(productCreatorStub{}),
		search.NewHandler(productSearcherRouteStub{}),
	)
}

func TestRoutesExposeHealth(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusOK)
	}
}

func TestRoutesExposeReadiness(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/readyz", nil)

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusOK)
	}
}

func TestRoutesExposeAdminProductCreate(t *testing.T) {
	recorder := httptest.NewRecorder()
	body := `{"name":"Arc Chair","slug":"arc-chair","description":"Configurable chair.","informationSections":[]}`
	request := httptest.NewRequest(http.MethodPost, "/admin/products", strings.NewReader(body))

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusCreated, recorder.Body.String())
	}
}

func TestRoutesExposeAdminProductList(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/admin/products", nil)

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
}

func TestRoutesExposeAdminProductGet(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/admin/products/prod_12345678", nil)

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
}

func TestRoutesExposeAdminProductUpdate(t *testing.T) {
	recorder := httptest.NewRecorder()
	body := `{"name":"Arc Chair","slug":"arc-chair","description":"Configurable chair.","informationSections":[]}`
	request := httptest.NewRequest(http.MethodPut, "/admin/products/prod_12345678", strings.NewReader(body))

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
}

func TestRoutesExposeAdminProductSourceUpload(t *testing.T) {
	recorder := httptest.NewRecorder()
	body := "--lumin\r\nContent-Disposition: form-data; name=\"source\"; filename=\"source.glb\"\r\nContent-Type: model/gltf-binary\r\n\r\nglTF\r\n--lumin--\r\n"
	request := httptest.NewRequest(http.MethodPost, "/admin/products/prod_12345678/source-glb", strings.NewReader(body))
	request.Header.Set("Content-Type", "multipart/form-data; boundary=lumin")

	sourceRef := product.ObjectRef{Bucket: "lumin-source-glb", Key: "products/prod_12345678/source.glb", ContentType: "model/gltf-binary"}
	handler := product.NewHandler(productCreatorStub{}).
		WithSourceAssetStore(sourceAssetStoreRouteStub{ref: sourceRef}).
		WithEventPublisher(eventPublisherRouteStub{})

	routes(readyStub{}, handler, search.NewHandler(productSearcherRouteStub{})).ServeHTTP(recorder, request)

	if recorder.Code != http.StatusAccepted {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusAccepted, recorder.Body.String())
	}
}

func TestRoutesExposeCatalogProducts(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/products", nil)

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
}

func TestRoutesExposeCatalogSearch(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/search?q=chair", nil)

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
}

type sourceAssetStoreRouteStub struct {
	ref product.ObjectRef
}

func (stub sourceAssetStoreRouteStub) PutSourceAsset(_ context.Context, _ string, _ io.Reader, _ int64) (product.ObjectRef, error) {
	return stub.ref, nil
}

type eventPublisherRouteStub struct{}

func (eventPublisherRouteStub) PublishProductUpdated(context.Context, product.ProductUpdatedEvent) error {
	return nil
}

func (eventPublisherRouteStub) PublishProcessingTaskCreated(context.Context, product.TaskCreatedEvent) error {
	return nil
}

func TestPortFromEnv(t *testing.T) {
	tests := []struct {
		name    string
		value   string
		want    int
		wantErr bool
	}{
		{name: "default", want: defaultPort},
		{name: "configured", value: "9090", want: 9090},
		{name: "not a number", value: "http", wantErr: true},
		{name: "too low", value: "0", wantErr: true},
		{name: "too high", value: "65536", wantErr: true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := portFromEnv(test.value)
			if (err != nil) != test.wantErr {
				t.Fatalf("error = %v, wantErr %v", err, test.wantErr)
			}
			if got != test.want {
				t.Fatalf("port = %d, want %d", got, test.want)
			}
		})
	}
}
