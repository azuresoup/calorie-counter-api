package config

import (
	"fmt"

	"github.com/caarlos0/env/v11"
)

type Config struct {
	Port             string `env:"PORT" envDefault:"8080"`
	LogLevel         string `env:"LOG_LEVEL" envDefault:"info"`
	Env              string `env:"ENV" envDefault:"dev"`
	PostgresUser     string `env:"POSTGRES_USER,required"`
	PostgresPassword string `env:"POSTGRES_PASSWORD,required"`
	PostgresDB       string `env:"POSTGRES_DB,required"`
	PostgresHost     string `env:"POSTGRES_HOST" envDefault:"localhost"`
	PostgresPort     string `env:"POSTGRES_PORT" envDefault:"5432"`
}

func Load() (*Config, error) {
	cfg := &Config{}
	if err := env.Parse(cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}

func (c *Config) DatabaseURL() string {
	return fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
		c.PostgresUser, c.PostgresPassword, c.PostgresHost, c.PostgresPort, c.PostgresDB)
}
