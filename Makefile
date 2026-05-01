.PHONY: run build test lint migrate-up migrate-down docker-up docker-down

run:
	go run ./cmd/api

build:
	go build -o bin/api ./cmd/api

test:
	go test ./... -short

lint:
	golangci-lint run

migrate-up:
	@echo "TODO: migrate up"

migrate-down:
	@echo "TODO: migrate down"

docker-up:
	@echo "TODO: docker up"

docker-down:
	@echo "TODO: docker down"