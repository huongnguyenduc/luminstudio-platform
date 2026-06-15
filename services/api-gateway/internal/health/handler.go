package health

import (
	"context"
	"encoding/json"
	"net/http"
)

type response struct {
	Status string `json:"status"`
}

type Readiness interface {
	Check(context.Context) error
}

func Handler(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(response{Status: "ok"})
}

func ReadinessHandler(readiness Readiness) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		status := http.StatusOK
		body := response{Status: "ready"}
		if err := readiness.Check(request.Context()); err != nil {
			status = http.StatusServiceUnavailable
			body.Status = "unavailable"
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_ = json.NewEncoder(w).Encode(body)
	})
}
