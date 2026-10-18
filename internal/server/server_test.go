package server

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHandleRoot(t *testing.T) {
	s := New("8080", "2.0.2")

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rr := httptest.NewRecorder()

	s.Handler().ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, rr.Code)
	}

	expected := "Hello, DevOps! version=2.0.2\n"
	if !strings.Contains(rr.Body.String(), expected) {
		t.Fatalf("expected body %q, got %q", expected, rr.Body.String())
	}
}
