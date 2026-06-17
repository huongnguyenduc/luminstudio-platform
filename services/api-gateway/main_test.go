package main

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"lumin.studio/services/api-gateway/internal/cart"
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
	record := routeProductRecord(time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC))
	size := int64(3)
	record.ProcessingStatus = product.ProcessingCompleted
	record.SourceAsset = &product.ObjectRef{
		Bucket:      "lumin-source-glb",
		Key:         "products/prod_12345678/source.glb",
		ContentType: "model/gltf-binary",
		SizeBytes:   &size,
	}
	record.OptimizedAsset = &product.ObjectRef{
		Bucket:      "lumin-optimized-glb",
		Key:         "prod_12345678_low.glb",
		ContentType: "model/gltf-binary",
		SizeBytes:   &size,
	}
	record.SpriteAsset = &product.ObjectRef{
		Bucket:      "lumin-360-sprites",
		Key:         "prod_12345678_360_sprite.jpg",
		ContentType: "image/jpeg",
		SizeBytes:   &size,
	}
	return record, nil
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
		Price:            product.ProductPrice{AmountCents: 12900, Currency: "USD"},
		Categories:       []product.ProductCategory{{Slug: "chairs", Name: "Chairs"}},
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
			Price:            product.ProductPrice{AmountCents: 12900, Currency: "USD"},
			Categories:       []product.ProductCategory{{Slug: "chairs", Name: "Chairs"}},
			ProcessingStatus: product.ProcessingCompleted,
			UpdatedAt:        time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC),
		}},
	}, nil
}

func (productSearcherRouteStub) ListCategories(_ context.Context) ([]product.ProductCategory, error) {
	return []product.ProductCategory{{Slug: "chairs", Name: "Chairs"}}, nil
}

func testRoutes() http.Handler {
	return routes(
		readyStub{},
		product.NewHandler(productCreatorStub{}),
		search.NewHandler(productSearcherRouteStub{}),
		cart.NewHandler(cartStoreRouteStub{record: routeCartRecord(time.Date(2026, 6, 16, 12, 0, 0, 0, time.UTC))}, productCreatorStub{}),
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
	body := `{"name":"Arc Chair","slug":"arc-chair","description":"Configurable chair.","price":{"amountCents":12900,"currency":"USD"},"informationSections":[]}`
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
	body := `{"name":"Arc Chair","slug":"arc-chair","description":"Configurable chair.","price":{"amountCents":12900,"currency":"USD"},"informationSections":[]}`
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

	routes(readyStub{}, handler, search.NewHandler(productSearcherRouteStub{}), cart.NewHandler(cartStoreRouteStub{}, productCreatorStub{})).ServeHTTP(recorder, request)

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

func TestRoutesExposeCatalogCategories(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/categories", nil)

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
}

func TestRoutesExposeCatalogCategoryProducts(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/categories/chairs/products?sort=newest", nil)

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

func TestRoutesExposeCatalogProductSprite(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/products/prod_12345678/sprite", nil)
	searchHandler := search.NewHandler(productSearcherRouteStub{}).
		WithCatalogProductReader(productCreatorStub{}).
		WithSpriteAssetStore(spriteAssetStoreRouteStub{body: []byte{0xff, 0xd8, 0xff}})

	routes(readyStub{}, product.NewHandler(productCreatorStub{}), searchHandler, cart.NewHandler(cartStoreRouteStub{}, productCreatorStub{})).ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
	if recorder.Header().Get("Content-Type") != "image/jpeg" {
		t.Fatalf("content-type = %q", recorder.Header().Get("Content-Type"))
	}
}

func TestRoutesExposeCatalogProductDetail(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/products/prod_12345678?tier=low", nil)
	searchHandler := search.NewHandler(productSearcherRouteStub{}).
		WithCatalogProductReader(productCreatorStub{})

	routes(readyStub{}, product.NewHandler(productCreatorStub{}), searchHandler, cart.NewHandler(cartStoreRouteStub{}, productCreatorStub{})).ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), `"/catalog/products/prod_12345678/model?tier=low"`) {
		t.Fatalf("body missing model URL: %s", recorder.Body.String())
	}
}

func TestRoutesExposeCatalogProductModel(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/catalog/products/prod_12345678/model?tier=low", nil)
	searchHandler := search.NewHandler(productSearcherRouteStub{}).
		WithCatalogProductReader(productCreatorStub{}).
		WithModelAssetStore(modelAssetStoreRouteStub{body: []byte("glb")})

	routes(readyStub{}, product.NewHandler(productCreatorStub{}), searchHandler, cart.NewHandler(cartStoreRouteStub{}, productCreatorStub{})).ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
	if recorder.Header().Get("Content-Type") != "model/gltf-binary" {
		t.Fatalf("content-type = %q", recorder.Header().Get("Content-Type"))
	}
}

func TestRoutesExposeCartCreate(t *testing.T) {
	recorder := httptest.NewRecorder()
	body := `{"items":[{"productId":"prod_12345678","selectedColors":{"mesh_body":"#FFFFFF"},"quantity":1,"selected":true}]}`
	request := httptest.NewRequest(http.MethodPost, "/cart", strings.NewReader(body))

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusCreated, recorder.Body.String())
	}
}

func TestRoutesExposeCartGet(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/cart/cart_12345678", nil)

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
}

func TestRoutesExposeCartUpdate(t *testing.T) {
	recorder := httptest.NewRecorder()
	body := `{"items":[{"productId":"prod_12345678","selectedColors":{"mesh_body":"#FFFFFF"},"quantity":2,"selected":true}]}`
	request := httptest.NewRequest(http.MethodPut, "/cart/cart_12345678", strings.NewReader(body))

	testRoutes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
}

type cartStoreRouteStub struct {
	record cart.Record
}

func (stub cartStoreRouteStub) InsertCart(_ context.Context, _ string, _ []cart.ItemSnapshot, _ time.Time) (cart.Record, error) {
	return stub.record, nil
}

func (stub cartStoreRouteStub) UpdateCart(_ context.Context, _ string, _ []cart.ItemSnapshot, _ time.Time) (cart.Record, error) {
	return stub.record, nil
}

func (stub cartStoreRouteStub) GetCart(_ context.Context, _ string) (cart.Record, error) {
	return stub.record, nil
}

func routeCartRecord(now time.Time) cart.Record {
	items := []cart.ItemSnapshot{{
		ProductID:               "prod_12345678",
		ProductName:             "Arc Chair",
		Price:                   product.ProductPrice{AmountCents: 12900, Currency: "USD"},
		Categories:              []product.ProductCategory{{Slug: "chairs", Name: "Chairs"}},
		SelectedColors:          map[string]string{"mesh_body": "#FFFFFF"},
		Quantity:                1,
		Selected:                true,
		ProductUpdatedAt:        now,
		ProductProcessingStatus: product.ProcessingCompleted,
	}}
	return cart.Record{
		ID:        "cart_12345678",
		Items:     items,
		Totals:    cart.CalculateTotals(items),
		CreatedAt: now,
		UpdatedAt: now,
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

type spriteAssetStoreRouteStub struct {
	body []byte
}

func (stub spriteAssetStoreRouteStub) GetSpriteAsset(_ context.Context, _ product.ObjectRef) (io.ReadCloser, error) {
	return io.NopCloser(strings.NewReader(string(stub.body))), nil
}

type modelAssetStoreRouteStub struct {
	body []byte
}

func (stub modelAssetStoreRouteStub) GetModelAsset(_ context.Context, _ product.ObjectRef) (io.ReadCloser, error) {
	return io.NopCloser(strings.NewReader(string(stub.body))), nil
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
