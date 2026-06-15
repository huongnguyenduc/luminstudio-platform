package product

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type creatorStub struct {
	record      ProductRecord
	records     []ProductRecord
	err         error
	called      bool
	id          string
	draft       ProductDraft
	now         time.Time
	requestedID string
}

func (stub *creatorStub) InsertProduct(_ context.Context, id string, draft ProductDraft, now time.Time) (ProductRecord, error) {
	stub.called = true
	stub.id = id
	stub.draft = draft
	stub.now = now
	return stub.record, stub.err
}

func (stub *creatorStub) UpdateProduct(_ context.Context, id string, draft ProductDraft, now time.Time) (ProductRecord, error) {
	stub.called = true
	stub.requestedID = id
	stub.draft = draft
	stub.now = now
	return stub.record, stub.err
}

func (stub *creatorStub) GetProduct(_ context.Context, id string) (ProductRecord, error) {
	stub.called = true
	stub.requestedID = id
	return stub.record, stub.err
}

func (stub *creatorStub) ListProducts(_ context.Context) ([]ProductRecord, error) {
	stub.called = true
	return stub.records, stub.err
}

func TestCreateProductPersistsValidatedDraft(t *testing.T) {
	now := time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC)
	record := validRecord(now)
	creator := &creatorStub{record: record}
	handler := NewHandler(creator)
	handler.now = func() time.Time { return now }
	handler.newID = func() (string, error) { return "prod_12345678", nil }

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/admin/products", strings.NewReader(validDraftJSON(t)))

	handler.CreateProduct(recorder, request)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusCreated, recorder.Body.String())
	}
	if !creator.called {
		t.Fatal("expected product creator to be called")
	}
	if creator.id != "prod_12345678" {
		t.Fatalf("id = %q", creator.id)
	}
	if creator.draft.Slug != "arc-chair" {
		t.Fatalf("slug = %q", creator.draft.Slug)
	}
	if !creator.now.Equal(now) {
		t.Fatalf("now = %s", creator.now)
	}
	var got ProductRecord
	if err := json.Unmarshal(recorder.Body.Bytes(), &got); err != nil {
		t.Fatalf("response was not product JSON: %v", err)
	}
	if got.ID != record.ID || got.ProcessingStatus != ProcessingNotStarted {
		t.Fatalf("unexpected response: %#v", got)
	}
}

func TestCreateProductRejectsInvalidDraft(t *testing.T) {
	creator := &creatorStub{}
	handler := NewHandler(creator)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/admin/products", strings.NewReader(`{"name":""}`))

	handler.CreateProduct(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
	if creator.called {
		t.Fatal("invalid draft must not reach persistence")
	}
}

func TestCreateProductRejectsTrailingJSON(t *testing.T) {
	handler := NewHandler(&creatorStub{})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/admin/products", strings.NewReader(validDraftJSON(t)+"{}"))

	handler.CreateProduct(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
}

func TestCreateProductReportsPersistenceFailure(t *testing.T) {
	handler := NewHandler(&creatorStub{err: errors.New("database unavailable")})
	handler.newID = func() (string, error) { return "prod_12345678", nil }

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/admin/products", strings.NewReader(validDraftJSON(t)))

	handler.CreateProduct(recorder, request)

	if recorder.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusInternalServerError)
	}
}

func TestGetProductReturnsRecord(t *testing.T) {
	now := time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC)
	repository := &creatorStub{record: validRecord(now)}
	handler := NewHandler(repository)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/admin/products/prod_12345678", nil)
	request.SetPathValue("id", "prod_12345678")

	handler.GetProduct(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
	if repository.requestedID != "prod_12345678" {
		t.Fatalf("requested id = %q", repository.requestedID)
	}
	var got ProductRecord
	if err := json.Unmarshal(recorder.Body.Bytes(), &got); err != nil {
		t.Fatalf("response was not product JSON: %v", err)
	}
	if got.ID != "prod_12345678" {
		t.Fatalf("id = %q", got.ID)
	}
}

func TestGetProductRejectsInvalidID(t *testing.T) {
	repository := &creatorStub{}
	handler := NewHandler(repository)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/admin/products/bad", nil)
	request.SetPathValue("id", "bad")

	handler.GetProduct(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
	if repository.called {
		t.Fatal("invalid id must not reach persistence")
	}
}

func TestGetProductReturnsNotFound(t *testing.T) {
	handler := NewHandler(&creatorStub{err: ErrProductNotFound})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/admin/products/prod_missing1", nil)
	request.SetPathValue("id", "prod_missing1")

	handler.GetProduct(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusNotFound)
	}
}

func TestUpdateProductPersistsValidatedDraft(t *testing.T) {
	now := time.Date(2026, 6, 15, 13, 0, 0, 0, time.UTC)
	record := validRecord(now)
	repository := &creatorStub{record: record}
	handler := NewHandler(repository)
	handler.now = func() time.Time { return now }

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPut, "/admin/products/prod_12345678", strings.NewReader(validDraftJSON(t)))
	request.SetPathValue("id", "prod_12345678")

	handler.UpdateProduct(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
	if repository.requestedID != "prod_12345678" {
		t.Fatalf("requested id = %q", repository.requestedID)
	}
	if repository.draft.Slug != "arc-chair" {
		t.Fatalf("slug = %q", repository.draft.Slug)
	}
	if !repository.now.Equal(now) {
		t.Fatalf("now = %s", repository.now)
	}
	var got ProductRecord
	if err := json.Unmarshal(recorder.Body.Bytes(), &got); err != nil {
		t.Fatalf("response was not product JSON: %v", err)
	}
	if got.ID != "prod_12345678" {
		t.Fatalf("id = %q", got.ID)
	}
}

func TestUpdateProductRejectsInvalidID(t *testing.T) {
	repository := &creatorStub{}
	handler := NewHandler(repository)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPut, "/admin/products/bad", strings.NewReader(validDraftJSON(t)))
	request.SetPathValue("id", "bad")

	handler.UpdateProduct(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
	if repository.called {
		t.Fatal("invalid id must not reach persistence")
	}
}

func TestUpdateProductRejectsInvalidDraft(t *testing.T) {
	repository := &creatorStub{}
	handler := NewHandler(repository)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPut, "/admin/products/prod_12345678", strings.NewReader(`{"name":""}`))
	request.SetPathValue("id", "prod_12345678")

	handler.UpdateProduct(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
	if repository.called {
		t.Fatal("invalid draft must not reach persistence")
	}
}

func TestUpdateProductRejectsTrailingJSON(t *testing.T) {
	handler := NewHandler(&creatorStub{})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPut, "/admin/products/prod_12345678", strings.NewReader(validDraftJSON(t)+"{}"))
	request.SetPathValue("id", "prod_12345678")

	handler.UpdateProduct(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
}

func TestUpdateProductReturnsNotFound(t *testing.T) {
	handler := NewHandler(&creatorStub{err: ErrProductNotFound})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPut, "/admin/products/prod_missing1", strings.NewReader(validDraftJSON(t)))
	request.SetPathValue("id", "prod_missing1")

	handler.UpdateProduct(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusNotFound)
	}
}

func TestListProductsReturnsRecords(t *testing.T) {
	now := time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC)
	handler := NewHandler(&creatorStub{records: []ProductRecord{validRecord(now)}})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/admin/products", nil)

	handler.ListProducts(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
	var got []ProductRecord
	if err := json.Unmarshal(recorder.Body.Bytes(), &got); err != nil {
		t.Fatalf("response was not product list JSON: %v", err)
	}
	if len(got) != 1 || got[0].ID != "prod_12345678" {
		t.Fatalf("unexpected products: %#v", got)
	}
}

func TestNewIDMatchesProductContract(t *testing.T) {
	id, err := NewID()
	if err != nil {
		t.Fatalf("new id failed: %v", err)
	}
	if !productIDPattern.MatchString(id) {
		t.Fatalf("id %q does not match product id contract", id)
	}
}

func validDraftJSON(t *testing.T) string {
	t.Helper()
	data, err := json.Marshal(validDraft())
	if err != nil {
		t.Fatalf("marshal valid draft: %v", err)
	}
	return string(data)
}

func validRecord(now time.Time) ProductRecord {
	draft := validDraft()
	return ProductRecord{
		ID:                  "prod_12345678",
		Name:                draft.Name,
		Slug:                draft.Slug,
		Description:         draft.Description,
		InformationSections: draft.InformationSections,
		MeshColorConfig:     draft.MeshColorConfig,
		SourceAsset:         draft.SourceAsset,
		CreatedAt:           now,
		UpdatedAt:           now,
		ProcessingStatus:    ProcessingNotStarted,
	}
}
