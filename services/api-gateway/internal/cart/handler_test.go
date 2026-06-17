package cart

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

type repositoryStub struct {
	record Record
	err    error
}

func (stub repositoryStub) InsertCart(context.Context, string, []ItemSnapshot, time.Time) (Record, error) {
	return stub.record, stub.err
}

func (stub repositoryStub) UpdateCart(context.Context, string, []ItemSnapshot, time.Time) (Record, error) {
	return stub.record, stub.err
}

func (stub repositoryStub) GetCart(context.Context, string) (Record, error) {
	return stub.record, stub.err
}

type productReaderStub struct {
	record product.ProductRecord
	err    error
}

func (stub productReaderStub) GetProduct(context.Context, string) (product.ProductRecord, error) {
	return stub.record, stub.err
}

func TestCreateCartSnapshotsProductAndReturnsCreated(t *testing.T) {
	now := time.Date(2026, 6, 16, 12, 0, 0, 0, time.UTC)
	record := validCartRecord(now)
	handler := NewHandler(repositoryStub{record: record}, productReaderStub{record: validProduct(now)})
	handler.newID = func() (string, error) { return "cart_12345678", nil }
	handler.now = func() time.Time { return now }

	recorder := httptest.NewRecorder()
	body := `{"items":[{"productId":"prod_12345678","selectedColors":{"mesh_body":"#FFFFFF"},"quantity":1,"selected":true}]}`
	request := httptest.NewRequest(http.MethodPost, "/cart", strings.NewReader(body))

	handler.CreateCart(recorder, request)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusCreated, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), `"id":"cart_12345678"`) {
		t.Fatalf("body missing cart id: %s", recorder.Body.String())
	}
}

func TestCreateCartRejectsMissingProduct(t *testing.T) {
	handler := NewHandler(repositoryStub{}, productReaderStub{err: product.ErrProductNotFound})
	handler.newID = func() (string, error) { return "cart_12345678", nil }

	recorder := httptest.NewRecorder()
	body := `{"items":[{"productId":"prod_12345678","quantity":1,"selected":true}]}`
	request := httptest.NewRequest(http.MethodPost, "/cart", strings.NewReader(body))

	handler.CreateCart(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusBadRequest, recorder.Body.String())
	}
}

func TestUpdateCartReturnsNotFound(t *testing.T) {
	handler := NewHandler(repositoryStub{err: ErrCartNotFound}, productReaderStub{record: validProduct(time.Now())})

	recorder := httptest.NewRecorder()
	body := `{"items":[{"productId":"prod_12345678","quantity":1,"selected":true}]}`
	request := httptest.NewRequest(http.MethodPut, "/cart/cart_12345678", strings.NewReader(body))
	request.SetPathValue("id", "cart_12345678")

	handler.UpdateCart(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusNotFound, recorder.Body.String())
	}
}

func TestGetCartReturnsRecord(t *testing.T) {
	now := time.Date(2026, 6, 16, 12, 0, 0, 0, time.UTC)
	handler := NewHandler(repositoryStub{record: validCartRecord(now)}, productReaderStub{})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/cart/cart_12345678", nil)
	request.SetPathValue("id", "cart_12345678")

	handler.GetCart(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
}

func validCartRecord(now time.Time) Record {
	items := []ItemSnapshot{validCartItem(now)}
	return Record{
		ID:        "cart_12345678",
		Items:     items,
		Totals:    CalculateTotals(items),
		CreatedAt: now,
		UpdatedAt: now,
	}
}
