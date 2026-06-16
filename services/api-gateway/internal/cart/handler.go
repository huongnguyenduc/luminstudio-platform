package cart

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
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

const maxCartRequestBytes = 1 << 20

type Repository interface {
	InsertCart(ctx context.Context, id string, items []ItemSnapshot, now time.Time) (Record, error)
	UpdateCart(ctx context.Context, id string, items []ItemSnapshot, now time.Time) (Record, error)
	GetCart(ctx context.Context, id string) (Record, error)
}

type ProductReader interface {
	GetProduct(ctx context.Context, id string) (product.ProductRecord, error)
}

type Handler struct {
	repository Repository
	products   ProductReader
	now        func() time.Time
	newID      func() (string, error)
}

func NewHandler(repository Repository, products ProductReader) Handler {
	return Handler{
		repository: repository,
		products:   products,
		now:        func() time.Time { return time.Now().UTC() },
		newID:      NewID,
	}
}

func (handler Handler) CreateCart(response http.ResponseWriter, request *http.Request) {
	if handler.repository == nil || handler.products == nil {
		writeError(response, http.StatusServiceUnavailable, "cart persistence is not configured")
		return
	}
	upsert, ok := handler.decodeUpsertRequest(response, request)
	if !ok {
		return
	}
	items, ok := handler.snapshotItems(response, request, upsert)
	if !ok {
		return
	}
	id, err := handler.newID()
	if err != nil {
		writeError(response, http.StatusInternalServerError, "could not allocate cart id")
		return
	}
	record, err := handler.repository.InsertCart(request.Context(), id, items, handler.now())
	if err != nil {
		slog.ErrorContext(request.Context(), "create cart failed", "error", err)
		writeError(response, http.StatusInternalServerError, "could not create cart")
		return
	}
	writeJSON(response, http.StatusCreated, record)
}

func (handler Handler) GetCart(response http.ResponseWriter, request *http.Request) {
	if handler.repository == nil {
		writeError(response, http.StatusServiceUnavailable, "cart persistence is not configured")
		return
	}
	id := request.PathValue("id")
	if !ValidCartID(id) {
		writeError(response, http.StatusBadRequest, "id must match the v1 cart id contract")
		return
	}
	record, err := handler.repository.GetCart(request.Context(), id)
	if err != nil {
		if errors.Is(err, ErrCartNotFound) {
			writeError(response, http.StatusNotFound, "cart not found")
			return
		}
		writeError(response, http.StatusInternalServerError, "could not read cart")
		return
	}
	writeJSON(response, http.StatusOK, record)
}

func (handler Handler) UpdateCart(response http.ResponseWriter, request *http.Request) {
	if handler.repository == nil || handler.products == nil {
		writeError(response, http.StatusServiceUnavailable, "cart persistence is not configured")
		return
	}
	id := request.PathValue("id")
	if !ValidCartID(id) {
		writeError(response, http.StatusBadRequest, "id must match the v1 cart id contract")
		return
	}
	upsert, ok := handler.decodeUpsertRequest(response, request)
	if !ok {
		return
	}
	items, ok := handler.snapshotItems(response, request, upsert)
	if !ok {
		return
	}
	record, err := handler.repository.UpdateCart(request.Context(), id, items, handler.now())
	if err != nil {
		if errors.Is(err, ErrCartNotFound) {
			writeError(response, http.StatusNotFound, "cart not found")
			return
		}
		writeError(response, http.StatusInternalServerError, "could not update cart")
		return
	}
	writeJSON(response, http.StatusOK, record)
}

func (handler Handler) decodeUpsertRequest(response http.ResponseWriter, request *http.Request) (UpsertRequest, bool) {
	var upsert UpsertRequest
	decoder := json.NewDecoder(http.MaxBytesReader(response, request.Body, maxCartRequestBytes))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&upsert); err != nil {
		writeError(response, http.StatusBadRequest, "request body must be a valid cart upsert request")
		return UpsertRequest{}, false
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		writeError(response, http.StatusBadRequest, "request body must contain one JSON object")
		return UpsertRequest{}, false
	}
	if err := upsert.Validate(); err != nil {
		writeError(response, http.StatusBadRequest, err.Error())
		return UpsertRequest{}, false
	}
	return upsert, true
}

func (handler Handler) snapshotItems(response http.ResponseWriter, request *http.Request, upsert UpsertRequest) ([]ItemSnapshot, bool) {
	products := make(map[string]product.ProductRecord, len(upsert.Items))
	for _, item := range upsert.Items {
		if _, ok := products[item.ProductID]; ok {
			continue
		}
		record, err := handler.products.GetProduct(request.Context(), item.ProductID)
		if err != nil {
			if errors.Is(err, product.ErrProductNotFound) {
				writeError(response, http.StatusBadRequest, "cart item product not found")
				return nil, false
			}
			writeError(response, http.StatusInternalServerError, "could not read cart item product")
			return nil, false
		}
		products[item.ProductID] = record
	}
	items, err := BuildSnapshots(upsert, products)
	if err != nil {
		writeError(response, http.StatusBadRequest, err.Error())
		return nil, false
	}
	return items, true
}

func NewID() (string, error) {
	for {
		var bytes [18]byte
		if _, err := rand.Read(bytes[:]); err != nil {
			return "", fmt.Errorf("read random bytes: %w", err)
		}
		encoded := base64.RawURLEncoding.EncodeToString(bytes[:])
		if isAlphaNumeric(encoded[0]) {
			return "cart_" + encoded, nil
		}
	}
}

func isAlphaNumeric(value byte) bool {
	return (value >= 'A' && value <= 'Z') || (value >= 'a' && value <= 'z') || (value >= '0' && value <= '9')
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
