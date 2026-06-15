package product

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"
)

const maxProductDraftBytes = 1 << 20

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

type Repository interface {
	Creator
	Updater
	Reader
}

type Handler struct {
	repository     Repository
	eventPublisher EventPublisher
	now            func() time.Time
	newID          func() (string, error)
	newEventID     func() (string, error)
	newCorrelation func() (string, error)
}

func NewHandler(repository Repository) Handler {
	return Handler{
		repository:     repository,
		now:            func() time.Time { return time.Now().UTC() },
		newID:          NewID,
		newEventID:     NewEventID,
		newCorrelation: NewCorrelationID,
	}
}

func (handler Handler) WithEventPublisher(publisher EventPublisher) Handler {
	handler.eventPublisher = publisher
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

func NewCorrelationID() (string, error) {
	return newPrefixedRandomID("corr_")
}

func newPrefixedRandomID(prefix string) (string, error) {
	var bytes [18]byte
	if _, err := rand.Read(bytes[:]); err != nil {
		return "", fmt.Errorf("read random bytes: %w", err)
	}
	encoded := base64.RawURLEncoding.EncodeToString(bytes[:])
	return prefix + encoded, nil
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
