package product

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"
)

const maxProductDraftBytes = 1 << 20
const maxSourceGLBBytes = 200 << 20

type Creator interface {
	InsertProduct(ctx context.Context, id string, draft ProductDraft, now time.Time) (ProductRecord, error)
}

type Updater interface {
	UpdateProduct(ctx context.Context, id string, draft ProductDraft, now time.Time) (ProductRecord, error)
}

type Reader interface {
	GetProduct(ctx context.Context, id string) (ProductRecord, error)
	ListProducts(ctx context.Context) ([]ProductRecord, error)
}

type SourceAssetQueuer interface {
	QueueSourceAsset(ctx context.Context, id string, sourceAsset ObjectRef, now time.Time) (ProductRecord, error)
}

type Repository interface {
	Creator
	Updater
	Reader
	SourceAssetQueuer
}

type SourceAssetStore interface {
	PutSourceAsset(ctx context.Context, productID string, source io.Reader, sizeBytes int64) (ObjectRef, error)
}

type Handler struct {
	repository     Repository
	sourceAssets   SourceAssetStore
	eventPublisher EventPublisher
	now            func() time.Time
	newID          func() (string, error)
	newTaskID      func() (string, error)
	newEventID     func() (string, error)
	newCorrelation func() (string, error)
}

func NewHandler(repository Repository) Handler {
	return Handler{
		repository:     repository,
		now:            func() time.Time { return time.Now().UTC() },
		newID:          NewID,
		newTaskID:      NewTaskID,
		newEventID:     NewEventID,
		newCorrelation: NewCorrelationID,
	}
}

func (handler Handler) WithEventPublisher(publisher EventPublisher) Handler {
	handler.eventPublisher = publisher
	return handler
}

func (handler Handler) WithSourceAssetStore(store SourceAssetStore) Handler {
	handler.sourceAssets = store
	return handler
}

func (handler Handler) CreateProduct(response http.ResponseWriter, request *http.Request) {
	if handler.repository == nil {
		writeError(response, http.StatusServiceUnavailable, "product persistence is not configured")
		return
	}

	var draft ProductDraft
	decoder := json.NewDecoder(http.MaxBytesReader(response, request.Body, maxProductDraftBytes))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&draft); err != nil {
		writeError(response, http.StatusBadRequest, "request body must be a valid product draft")
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		writeError(response, http.StatusBadRequest, "request body must contain one JSON object")
		return
	}
	if err := draft.Validate(); err != nil {
		writeError(response, http.StatusBadRequest, err.Error())
		return
	}
	correlationID, err := handler.correlationIDForRequest(request)
	if err != nil {
		if errors.Is(err, errInvalidCorrelationID) {
			writeError(response, http.StatusBadRequest, err.Error())
			return
		}
		writeError(response, http.StatusInternalServerError, "could not allocate correlation id")
		return
	}

	id, err := handler.newID()
	if err != nil {
		writeError(response, http.StatusInternalServerError, "could not allocate product id")
		return
	}
	record, err := handler.repository.InsertProduct(request.Context(), id, draft, handler.now())
	if err != nil {
		slog.ErrorContext(request.Context(), "create product failed", "error", err)
		writeError(response, http.StatusInternalServerError, "could not create product")
		return
	}
	if err := handler.publishProductUpdated(request.Context(), record, correlationID); err != nil {
		writeError(response, http.StatusBadGateway, "could not publish product update event")
		return
	}

	response.Header().Set("Content-Type", "application/json")
	response.WriteHeader(http.StatusCreated)
	if err := json.NewEncoder(response).Encode(record); err != nil {
		http.Error(response, "could not encode response", http.StatusInternalServerError)
	}
}

func (handler Handler) UploadProductSource(response http.ResponseWriter, request *http.Request) {
	if handler.repository == nil {
		writeError(response, http.StatusServiceUnavailable, "product persistence is not configured")
		return
	}
	if handler.sourceAssets == nil {
		writeError(response, http.StatusServiceUnavailable, "source asset storage is not configured")
		return
	}
	if handler.eventPublisher == nil {
		writeError(response, http.StatusServiceUnavailable, "processing event publication is not configured")
		return
	}

	id := request.PathValue("id")
	if !productIDPattern.MatchString(id) {
		writeError(response, http.StatusBadRequest, "id must match the v1 product id contract")
		return
	}
	existing, err := handler.repository.GetProduct(request.Context(), id)
	if err != nil {
		if errors.Is(err, ErrProductNotFound) {
			writeError(response, http.StatusNotFound, "product not found")
			return
		}
		writeError(response, http.StatusInternalServerError, "could not read product")
		return
	}
	if existing.MeshColorConfig == nil {
		writeError(response, http.StatusConflict, "meshColorConfig is required before source upload")
		return
	}
	if err := existing.MeshColorConfig.validate(); err != nil {
		writeError(response, http.StatusConflict, err.Error())
		return
	}
	correlationID, err := handler.correlationIDForRequest(request)
	if err != nil {
		if errors.Is(err, errInvalidCorrelationID) {
			writeError(response, http.StatusBadRequest, err.Error())
			return
		}
		writeError(response, http.StatusInternalServerError, "could not allocate correlation id")
		return
	}

	request.Body = http.MaxBytesReader(response, request.Body, maxSourceGLBBytes)
	if err := request.ParseMultipartForm(1 << 20); err != nil {
		writeError(response, http.StatusBadRequest, "request body must be multipart/form-data with a source GLB file")
		return
	}
	file, header, err := request.FormFile("source")
	if err != nil {
		writeError(response, http.StatusBadRequest, "source GLB file is required")
		return
	}
	defer file.Close()
	if header.Size <= 0 {
		writeError(response, http.StatusBadRequest, "source GLB file must not be empty")
		return
	}
	if !strings.HasSuffix(strings.ToLower(header.Filename), ".glb") {
		writeError(response, http.StatusBadRequest, "source filename must end with .glb")
		return
	}

	sourceAsset, err := handler.sourceAssets.PutSourceAsset(request.Context(), id, file, header.Size)
	if err != nil {
		writeError(response, http.StatusBadGateway, "could not store source GLB")
		return
	}
	record, err := handler.repository.QueueSourceAsset(request.Context(), id, sourceAsset, handler.now())
	if err != nil {
		if errors.Is(err, ErrProductNotFound) {
			writeError(response, http.StatusNotFound, "product not found")
			return
		}
		writeError(response, http.StatusInternalServerError, "could not queue source asset")
		return
	}
	if err := handler.publishProductUpdated(request.Context(), record, correlationID); err != nil {
		writeError(response, http.StatusBadGateway, "could not publish product update event")
		return
	}
	if err := handler.publishProcessingTaskCreated(request.Context(), record, correlationID); err != nil {
		writeError(response, http.StatusBadGateway, "could not publish processing task event")
		return
	}

	writeJSON(response, http.StatusAccepted, record)
}

func (handler Handler) GetProduct(response http.ResponseWriter, request *http.Request) {
	if handler.repository == nil {
		writeError(response, http.StatusServiceUnavailable, "product persistence is not configured")
		return
	}

	id := request.PathValue("id")
	if !productIDPattern.MatchString(id) {
		writeError(response, http.StatusBadRequest, "id must match the v1 product id contract")
		return
	}
	record, err := handler.repository.GetProduct(request.Context(), id)
	if err != nil {
		if errors.Is(err, ErrProductNotFound) {
			writeError(response, http.StatusNotFound, "product not found")
			return
		}
		writeError(response, http.StatusInternalServerError, "could not read product")
		return
	}

	writeJSON(response, http.StatusOK, record)
}

func (handler Handler) UpdateProduct(response http.ResponseWriter, request *http.Request) {
	if handler.repository == nil {
		writeError(response, http.StatusServiceUnavailable, "product persistence is not configured")
		return
	}

	id := request.PathValue("id")
	if !productIDPattern.MatchString(id) {
		writeError(response, http.StatusBadRequest, "id must match the v1 product id contract")
		return
	}
	var draft ProductDraft
	decoder := json.NewDecoder(http.MaxBytesReader(response, request.Body, maxProductDraftBytes))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&draft); err != nil {
		writeError(response, http.StatusBadRequest, "request body must be a valid product draft")
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		writeError(response, http.StatusBadRequest, "request body must contain one JSON object")
		return
	}
	if err := draft.Validate(); err != nil {
		writeError(response, http.StatusBadRequest, err.Error())
		return
	}
	correlationID, err := handler.correlationIDForRequest(request)
	if err != nil {
		if errors.Is(err, errInvalidCorrelationID) {
			writeError(response, http.StatusBadRequest, err.Error())
			return
		}
		writeError(response, http.StatusInternalServerError, "could not allocate correlation id")
		return
	}

	record, err := handler.repository.UpdateProduct(request.Context(), id, draft, handler.now())
	if err != nil {
		if errors.Is(err, ErrProductNotFound) {
			writeError(response, http.StatusNotFound, "product not found")
			return
		}
		writeError(response, http.StatusInternalServerError, "could not update product")
		return
	}
	if err := handler.publishProductUpdated(request.Context(), record, correlationID); err != nil {
		writeError(response, http.StatusBadGateway, "could not publish product update event")
		return
	}

	writeJSON(response, http.StatusOK, record)
}

func (handler Handler) ListProducts(response http.ResponseWriter, request *http.Request) {
	if handler.repository == nil {
		writeError(response, http.StatusServiceUnavailable, "product persistence is not configured")
		return
	}

	records, err := handler.repository.ListProducts(request.Context())
	if err != nil {
		writeError(response, http.StatusInternalServerError, "could not list products")
		return
	}

	writeJSON(response, http.StatusOK, records)
}

func NewID() (string, error) {
	return newPrefixedRandomID("prod_")
}

func NewEventID() (string, error) {
	return newPrefixedRandomID("evt_")
}

func NewTaskID() (string, error) {
	return newPrefixedRandomID("task_")
}

func NewCorrelationID() (string, error) {
	return newPrefixedRandomID("corr_")
}

func newPrefixedRandomID(prefix string) (string, error) {
	for {
		var bytes [18]byte
		if _, err := rand.Read(bytes[:]); err != nil {
			return "", fmt.Errorf("read random bytes: %w", err)
		}
		encoded := base64.RawURLEncoding.EncodeToString(bytes[:])
		if isAlphaNumeric(encoded[0]) {
			return prefix + encoded, nil
		}
	}
}

func isAlphaNumeric(value byte) bool {
	return (value >= 'A' && value <= 'Z') || (value >= 'a' && value <= 'z') || (value >= '0' && value <= '9')
}

func (handler Handler) publishProcessingTaskCreated(ctx context.Context, record ProductRecord, correlationID string) error {
	eventID, err := handler.newEventID()
	if err != nil {
		return fmt.Errorf("allocate event id: %w", err)
	}
	taskID, err := handler.newTaskID()
	if err != nil {
		return fmt.Errorf("allocate task id: %w", err)
	}
	event, err := NewTaskCreatedEvent(eventID, correlationID, taskID, record)
	if err != nil {
		return err
	}
	return handler.eventPublisher.PublishProcessingTaskCreated(ctx, event)
}

func (handler Handler) correlationIDForRequest(request *http.Request) (string, error) {
	if handler.eventPublisher == nil {
		return "", nil
	}
	correlationID := request.Header.Get(correlationIDHeader)
	if correlationID != "" {
		if !validCorrelationID(correlationID) {
			return "", errInvalidCorrelationID
		}
		return correlationID, nil
	}
	correlationID, err := handler.newCorrelation()
	if err != nil {
		return "", err
	}
	return correlationID, nil
}

func (handler Handler) publishProductUpdated(ctx context.Context, record ProductRecord, correlationID string) error {
	if handler.eventPublisher == nil {
		return nil
	}
	eventID, err := handler.newEventID()
	if err != nil {
		return fmt.Errorf("allocate event id: %w", err)
	}
	event, err := NewProductUpdatedEvent(eventID, correlationID, record)
	if err != nil {
		return err
	}
	return handler.eventPublisher.PublishProductUpdated(ctx, event)
}

func writeJSON(response http.ResponseWriter, status int, payload any) {
	response.Header().Set("Content-Type", "application/json")
	response.WriteHeader(status)
	if err := json.NewEncoder(response).Encode(payload); err != nil {
		http.Error(response, "could not encode response", http.StatusInternalServerError)
	}
}

func writeError(response http.ResponseWriter, status int, message string) {
	response.Header().Set("Content-Type", "application/json")
	response.WriteHeader(status)
	_ = json.NewEncoder(response).Encode(map[string]string{"error": message})
}
