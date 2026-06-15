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

type Reader interface {
	GetProduct(ctx context.Context, id string) (ProductRecord, error)
	ListProducts(ctx context.Context) ([]ProductRecord, error)
}

type Repository interface {
	Creator
	Reader
}

type Handler struct {
	repository Repository
	now        func() time.Time
	newID      func() (string, error)
}

func NewHandler(repository Repository) Handler {
	return Handler{
		repository: repository,
		now:        func() time.Time { return time.Now().UTC() },
		newID:      NewID,
	}
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
	var bytes [18]byte
	if _, err := rand.Read(bytes[:]); err != nil {
		return "", fmt.Errorf("read random bytes: %w", err)
	}
	encoded := base64.RawURLEncoding.EncodeToString(bytes[:])
	return "prod_" + encoded, nil
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
