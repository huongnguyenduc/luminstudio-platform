package health

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

type readinessStub struct {
	err error
}

func (stub readinessStub) Check(context.Context) error {
	return stub.err
}

func TestHandler(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)

	Handler(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusOK)
	}
	if got, want := recorder.Header().Get("Content-Type"), "application/json"; got != want {
		t.Fatalf("content type = %q, want %q", got, want)
	}
	if got, want := recorder.Body.String(), "{\"status\":\"ok\"}\n"; got != want {
		t.Fatalf("body = %q, want %q", got, want)
	}
}

func TestReadinessHandler(t *testing.T) {
	tests := []struct {
		name       string
		err        error
		wantStatus int
		wantBody   string
	}{
		{name: "ready", wantStatus: http.StatusOK, wantBody: "{\"status\":\"ready\"}\n"},
		{name: "unavailable", err: errors.New("dependency unavailable"), wantStatus: http.StatusServiceUnavailable, wantBody: "{\"status\":\"unavailable\"}\n"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			recorder := httptest.NewRecorder()
			request := httptest.NewRequest(http.MethodGet, "/readyz", nil)

			ReadinessHandler(readinessStub{err: test.err}).ServeHTTP(recorder, request)

			if recorder.Code != test.wantStatus {
				t.Fatalf("status = %d, want %d", recorder.Code, test.wantStatus)
			}
			if got := recorder.Body.String(); got != test.wantBody {
				t.Fatalf("body = %q, want %q", got, test.wantBody)
			}
		})
	}
}
