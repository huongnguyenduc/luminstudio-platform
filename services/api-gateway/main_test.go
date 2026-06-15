package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

type readyStub struct {
	err error
}

func (stub readyStub) Check(context.Context) error {
	return stub.err
}

type productCreatorStub struct{}

func (productCreatorStub) InsertProduct(_ context.Context, _ string, _ product.ProductDraft, now time.Time) (product.ProductRecord, error) {
	return product.ProductRecord{
		ID:               "prod_12345678",
		Name:             "Arc Chair",
		Slug:             "arc-chair",
		Description:      "Configurable chair.",
		CreatedAt:        now,
		UpdatedAt:        now,
		ProcessingStatus: product.ProcessingNotStarted,
	}, nil
}

func TestRoutesExposeHealth(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)

	routes(readyStub{}, product.NewHandler(productCreatorStub{})).ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusOK)
	}
}

func TestRoutesExposeReadiness(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/readyz", nil)

	routes(readyStub{}, product.NewHandler(productCreatorStub{})).ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusOK)
	}
}

func TestRoutesExposeAdminProductCreate(t *testing.T) {
	recorder := httptest.NewRecorder()
	body := `{"name":"Arc Chair","slug":"arc-chair","description":"Configurable chair.","informationSections":[]}`
	request := httptest.NewRequest(http.MethodPost, "/admin/products", strings.NewReader(body))

	routes(readyStub{}, product.NewHandler(productCreatorStub{})).ServeHTTP(recorder, request)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d, body %s", recorder.Code, http.StatusCreated, recorder.Body.String())
	}
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
