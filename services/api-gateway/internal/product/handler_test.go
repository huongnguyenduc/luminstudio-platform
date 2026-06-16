package product

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"mime/multipart"
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

type eventPublisherStub struct {
	event     ProductUpdatedEvent
	taskEvent TaskCreatedEvent
	err       error
	calls     int
	taskCalls int
}

func (stub *eventPublisherStub) PublishProductUpdated(_ context.Context, event ProductUpdatedEvent) error {
	stub.calls++
	stub.event = event
	return stub.err
}

func (stub *eventPublisherStub) PublishProcessingTaskCreated(_ context.Context, event TaskCreatedEvent) error {
	stub.taskCalls++
	stub.taskEvent = event
	return stub.err
}

type sourceAssetStoreStub struct {
	ref       ObjectRef
	err       error
	called    bool
	productID string
	sizeBytes int64
}

func (stub *sourceAssetStoreStub) PutSourceAsset(_ context.Context, productID string, _ io.Reader, sizeBytes int64) (ObjectRef, error) {
	stub.called = true
	stub.productID = productID
	stub.sizeBytes = sizeBytes
	return stub.ref, stub.err
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

func (stub *creatorStub) QueueSourceAsset(_ context.Context, id string, sourceAsset ObjectRef, now time.Time) (ProductRecord, error) {
	stub.called = true
	stub.requestedID = id
	stub.now = now
	if stub.err != nil {
		return ProductRecord{}, stub.err
	}
	record := stub.record
	record.SourceAsset = &sourceAsset
	record.ProcessingStatus = ProcessingQueued
	record.UpdatedAt = now
	return record, nil
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
	publisher := &eventPublisherStub{}
	handler := NewHandler(creator)
	handler = handler.WithEventPublisher(publisher)
	handler.now = func() time.Time { return now }
	handler.newID = func() (string, error) { return "prod_12345678", nil }
	handler.newEventID = func() (string, error) { return "evt_12345678", nil }
	handler.newCorrelation = func() (string, error) { return "corr_generated", nil }

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/admin/products", strings.NewReader(validDraftJSON(t)))
	request.Header.Set(correlationIDHeader, "corr_request")

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
	if publisher.calls != 1 {
		t.Fatalf("publisher calls = %d, want 1", publisher.calls)
	}
	if publisher.event.ID != "evt_12345678" || publisher.event.Type != productUpdatedEventType {
		t.Fatalf("unexpected event envelope: %#v", publisher.event)
	}
	if publisher.event.SchemaVersion != eventSchemaVersion || publisher.event.CorrelationID != "corr_request" {
		t.Fatalf("unexpected event metadata: %#v", publisher.event)
	}
	if publisher.event.Payload.ProductID != record.ID || !publisher.event.Payload.ChangedAt.Equal(now) {
		t.Fatalf("unexpected event payload: %#v", publisher.event.Payload)
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

func TestCreateProductRejectsInvalidCorrelationID(t *testing.T) {
	creator := &creatorStub{}
	handler := NewHandler(creator).WithEventPublisher(&eventPublisherStub{})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/admin/products", strings.NewReader(validDraftJSON(t)))
	request.Header.Set(correlationIDHeader, "bad")

	handler.CreateProduct(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
	if creator.called {
		t.Fatal("invalid correlation id must not reach persistence")
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

func TestCreateProductReportsEventPublicationFailure(t *testing.T) {
	now := time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC)
	publisher := &eventPublisherStub{err: errors.New("nats unavailable")}
	handler := NewHandler(&creatorStub{record: validRecord(now)}).WithEventPublisher(publisher)
	handler.newID = func() (string, error) { return "prod_12345678", nil }
	handler.newEventID = func() (string, error) { return "evt_12345678", nil }
	handler.newCorrelation = func() (string, error) { return "corr_generated", nil }

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/admin/products", strings.NewReader(validDraftJSON(t)))

	handler.CreateProduct(recorder, request)

	if recorder.Code != http.StatusBadGateway {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadGateway)
	}
	if publisher.calls != 1 {
		t.Fatalf("publisher calls = %d, want 1", publisher.calls)
	}
}

func TestUploadProductSourceStoresAssetQueuesRecordAndPublishesTask(t *testing.T) {
	now := time.Date(2026, 6, 15, 15, 0, 0, 0, time.UTC)
	repository := &creatorStub{record: validRecord(now)}
	sourceRef := ObjectRef{
		Bucket:      "lumin-source-glb",
		Key:         "products/prod_12345678/source.glb",
		ContentType: "model/gltf-binary",
	}
	sourceStore := &sourceAssetStoreStub{ref: sourceRef}
	publisher := &eventPublisherStub{}
	handler := NewHandler(repository).
		WithSourceAssetStore(sourceStore).
		WithEventPublisher(publisher)
	handler.now = func() time.Time { return now }
	handler.newEventID = func() (string, error) { return "evt_12345678", nil }
	handler.newTaskID = func() (string, error) { return "task_12345678", nil }
	handler.newCorrelation = func() (string, error) { return "corr_generated", nil }

	recorder := httptest.NewRecorder()
	request := newSourceUploadRequest(t, "/admin/products/prod_12345678/source-glb", "source.glb", []byte("glTF"))
	request.SetPathValue("id", "prod_12345678")
	request.Header.Set(correlationIDHeader, "corr_request")

	handler.UploadProductSource(recorder, request)

	if recorder.Code != http.StatusAccepted {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusAccepted, recorder.Body.String())
	}
	if sourceStore.productID != "prod_12345678" || sourceStore.sizeBytes != 4 {
		t.Fatalf("unexpected source store call: %#v", sourceStore)
	}
	if repository.requestedID != "prod_12345678" {
		t.Fatalf("queued id = %q", repository.requestedID)
	}
	var got ProductRecord
	if err := json.Unmarshal(recorder.Body.Bytes(), &got); err != nil {
		t.Fatalf("response was not product JSON: %v", err)
	}
	if got.ProcessingStatus != ProcessingQueued || got.SourceAsset == nil {
		t.Fatalf("unexpected queued record: %#v", got)
	}
	if publisher.calls != 1 || publisher.event.Type != productUpdatedEventType {
		t.Fatalf("unexpected product.updated publication: %#v", publisher)
	}
	if publisher.taskCalls != 1 {
		t.Fatalf("task publications = %d, want 1", publisher.taskCalls)
	}
	if publisher.taskEvent.Type != taskCreatedEventType || publisher.taskEvent.Payload.TaskID != "task_12345678" {
		t.Fatalf("unexpected task event: %#v", publisher.taskEvent)
	}
	if publisher.taskEvent.CorrelationID != "corr_request" || publisher.taskEvent.Payload.ProductID != "prod_12345678" {
		t.Fatalf("unexpected task metadata: %#v", publisher.taskEvent)
	}
}

func TestUploadProductSourceRequiresMeshColorConfig(t *testing.T) {
	now := time.Date(2026, 6, 15, 15, 0, 0, 0, time.UTC)
	record := validRecord(now)
	record.MeshColorConfig = nil
	sourceStore := &sourceAssetStoreStub{}
	handler := NewHandler(&creatorStub{record: record}).
		WithSourceAssetStore(sourceStore).
		WithEventPublisher(&eventPublisherStub{})

	recorder := httptest.NewRecorder()
	request := newSourceUploadRequest(t, "/admin/products/prod_12345678/source-glb", "source.glb", []byte("glTF"))
	request.SetPathValue("id", "prod_12345678")

	handler.UploadProductSource(recorder, request)

	if recorder.Code != http.StatusConflict {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusConflict)
	}
	if sourceStore.called {
		t.Fatal("source file must not be stored when mesh config is missing")
	}
}

func TestUploadProductSourceRejectsNonGLBFilename(t *testing.T) {
	now := time.Date(2026, 6, 15, 15, 0, 0, 0, time.UTC)
	sourceStore := &sourceAssetStoreStub{}
	handler := NewHandler(&creatorStub{record: validRecord(now)}).
		WithSourceAssetStore(sourceStore).
		WithEventPublisher(&eventPublisherStub{})
	handler.newCorrelation = func() (string, error) { return "corr_generated", nil }

	recorder := httptest.NewRecorder()
	request := newSourceUploadRequest(t, "/admin/products/prod_12345678/source-glb", "source.txt", []byte("glTF"))
	request.SetPathValue("id", "prod_12345678")

	handler.UploadProductSource(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
	if sourceStore.called {
		t.Fatal("invalid source file must not be stored")
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
	publisher := &eventPublisherStub{}
	handler := NewHandler(repository)
	handler = handler.WithEventPublisher(publisher)
	handler.now = func() time.Time { return now }
	handler.newEventID = func() (string, error) { return "evt_12345678", nil }
	handler.newCorrelation = func() (string, error) { return "corr_generated", nil }

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
	if publisher.calls != 1 {
		t.Fatalf("publisher calls = %d, want 1", publisher.calls)
	}
	if publisher.event.Payload.ProductID != "prod_12345678" || publisher.event.CorrelationID != "corr_generated" {
		t.Fatalf("unexpected product.updated event: %#v", publisher.event)
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

func TestUpdateProductReportsEventPublicationFailure(t *testing.T) {
	now := time.Date(2026, 6, 15, 13, 0, 0, 0, time.UTC)
	publisher := &eventPublisherStub{err: errors.New("nats unavailable")}
	handler := NewHandler(&creatorStub{record: validRecord(now)}).WithEventPublisher(publisher)
	handler.newEventID = func() (string, error) { return "evt_12345678", nil }
	handler.newCorrelation = func() (string, error) { return "corr_generated", nil }

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPut, "/admin/products/prod_12345678", strings.NewReader(validDraftJSON(t)))
	request.SetPathValue("id", "prod_12345678")

	handler.UpdateProduct(recorder, request)

	if recorder.Code != http.StatusBadGateway {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadGateway)
	}
	if publisher.calls != 1 {
		t.Fatalf("publisher calls = %d, want 1", publisher.calls)
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

func TestNewProductUpdatedEventMatchesContract(t *testing.T) {
	now := time.Date(2026, 6, 15, 13, 0, 0, 0, time.UTC)

	event, err := NewProductUpdatedEvent("evt_12345678", "corr_12345678", validRecord(now))
	if err != nil {
		t.Fatalf("build product.updated event: %v", err)
	}

	if event.Type != "product.updated" || event.SchemaVersion != "v1" {
		t.Fatalf("unexpected envelope: %#v", event)
	}
	if event.Payload.ProductID != "prod_12345678" || !event.Payload.ChangedAt.Equal(now) {
		t.Fatalf("unexpected payload: %#v", event.Payload)
	}
}

func TestNewTaskIDMatchesProcessingTaskContract(t *testing.T) {
	id, err := NewTaskID()
	if err != nil {
		t.Fatalf("new task id failed: %v", err)
	}
	if !taskIDPattern.MatchString(id) {
		t.Fatalf("task id %q does not match contract", id)
	}
}

func TestNewTaskCreatedEventMatchesContract(t *testing.T) {
	now := time.Date(2026, 6, 15, 15, 0, 0, 0, time.UTC)
	record := validRecord(now)
	record.ProcessingStatus = ProcessingQueued

	event, err := NewTaskCreatedEvent("evt_12345678", "corr_12345678", "task_12345678", record)
	if err != nil {
		t.Fatalf("build 3d.task.created event: %v", err)
	}

	if event.Type != "3d.task.created" || event.SchemaVersion != "v1" {
		t.Fatalf("unexpected envelope: %#v", event)
	}
	if event.Payload.TaskID != "task_12345678" || event.Payload.ProductID != "prod_12345678" {
		t.Fatalf("unexpected payload: %#v", event.Payload)
	}
	if event.Payload.SourceAsset.Bucket != "lumin-source-glb" || event.Payload.MeshColorConfig["mesh_body"].Default != "#FFFFFF" {
		t.Fatalf("unexpected task payload: %#v", event.Payload)
	}
}

func newSourceUploadRequest(t *testing.T, target, filename string, payload []byte) *http.Request {
	t.Helper()
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, err := writer.CreateFormFile("source", filename)
	if err != nil {
		t.Fatalf("create multipart source file: %v", err)
	}
	if _, err := part.Write(payload); err != nil {
		t.Fatalf("write multipart source file: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close multipart writer: %v", err)
	}
	request := httptest.NewRequest(http.MethodPost, target, body)
	request.Header.Set("Content-Type", writer.FormDataContentType())
	return request
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
		Price:               draft.Price,
		InformationSections: draft.InformationSections,
		MeshColorConfig:     draft.MeshColorConfig,
		SourceAsset:         draft.SourceAsset,
		CreatedAt:           now,
		UpdatedAt:           now,
		ProcessingStatus:    ProcessingNotStarted,
	}
}
