package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"

	"github.com/joho/godotenv"

	"github.com/jackc/pgx/v5/pgxpool"

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

	dbpool, err := pgxpool.New(context.Background(), cfg.DatabaseURL())
	if err != nil {
		slog.Error("Unable to create connection pool", "error", err)
		os.Exit(1)
	}
	defer dbpool.Close()

	if err := dbpool.Ping(context.Background()); err != nil {
		slog.Error("db ping failed", "error", err)
		os.Exit(1)
	}
	slog.Info("database connected")

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", handlers.Health)

	log.Info("server starting", "port", cfg.Port, "env", cfg.Env)
	if err := http.ListenAndServe(":"+cfg.Port, mux); err != nil {
		log.Error("server failed", "error", err)
		os.Exit(1)
	}
}
