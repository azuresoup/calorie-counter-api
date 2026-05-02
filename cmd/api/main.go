package main

import (
	"log/slog"
	"net/http"
	"os"

	"github.com/joho/godotenv"

	"github.com/azuresoup/calorie-counter-api/internal/config"
	"github.com/azuresoup/calorie-counter-api/internal/logger"
	"github.com/azuresoup/calorie-counter-api/internal/transport/http/handlers"
)

func main() {
	_ = godotenv.Load()

	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	log := logger.New(cfg.LogLevel)
	slog.SetDefault(log)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", handlers.Health)

	log.Info("server starting", "port", cfg.Port, "env", cfg.Env)
	if err := http.ListenAndServe(":"+cfg.Port, mux); err != nil {
		log.Error("server failed", "error", err)
		os.Exit(1)
	}
}
