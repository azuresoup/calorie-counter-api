package main

import (
	"encoding/json"
	"log"
	"log/slog"
	"net/http"
)

func Health(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
   	if err := json.NewEncoder(w).Encode(map[string]string{"status": "ok"}); err != nil {
    	slog.Error("failed to encode response", "error", err)
	}
}

func main() {
    http.HandleFunc("/healthz", Health)
    log.Fatal(http.ListenAndServe(":8080", nil))
}