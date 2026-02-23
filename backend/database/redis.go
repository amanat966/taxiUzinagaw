package database

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

var Redis *redis.Client

// ConnectRedis initializes a Redis client if REDIS_URL is set.
// It is best-effort: if Redis is unavailable, the app still starts.
func ConnectRedis() {
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		log.Println("Redis disabled: REDIS_URL is not set")
		return
	}

	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Printf("Redis disabled: invalid REDIS_URL: %v", err)
		return
	}

	client := redis.NewClient(opt)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		log.Printf("Redis disabled: ping failed: %v", err)
		_ = client.Close()
		return
	}

	Redis = client
	log.Println("Connected to Redis successfully")
}

