package product

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const maxProductDraftBytes = 1 << 20

type Creator interface {
	InsertProduct(ctx context.Context, id string, draft ProductDraft, now time.Time) (ProductRecord, error)
}

type Handler struct {
	creator Creator
	now     func() time.Time
	newID   func() (string, error)
}

func NewHandler(creator Creator) Handler {
	return Handler{
		creator: creator,
		now:     func() time.Time { return time.Now().UTC() },
		newID:   NewID,
	}
}

func (handler Handler) CreateProduct(response http.ResponseWriter, request *http.Request) {
	if handler.creator == nil {
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
	record, err := handler.creator.InsertProduct(request.Context(), id, draft, handler.now())
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

func NewID() (string, error) {
	var bytes [18]byte
	if _, err := rand.Read(bytes[:]); err != nil {
		return "", fmt.Errorf("read random bytes: %w", err)
	}
	encoded := base64.RawURLEncoding.EncodeToString(bytes[:])
	return "prod_" + encoded, nil
}

func writeError(response http.ResponseWriter, status int, message string) {
	response.Header().Set("Content-Type", "application/json")
	response.WriteHeader(status)
	_ = json.NewEncoder(response).Encode(map[string]string{"error": message})
}
