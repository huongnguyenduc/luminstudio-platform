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
	record ProductRecord
	err    error
	called bool
	id     string
	draft  ProductDraft
	now    time.Time
}

func (stub *creatorStub) InsertProduct(_ context.Context, id string, draft ProductDraft, now time.Time) (ProductRecord, error) {
	stub.called = true
	stub.id = id
	stub.draft = draft
	stub.now = now
	return stub.record, stub.err
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
