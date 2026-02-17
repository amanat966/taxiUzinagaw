package main

import (
	"log"

	"github.com/joho/godotenv"

	"taxi-fleet-backend/database"
	"taxi-fleet-backend/models"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using env vars")
	}

	database.Connect()

	log.Println("Running migrations...")
	// AutoMigrate doesn't change existing column types. Ensure orders.price is float.
	// Postgres: int -> double precision
	if err := database.DB.Exec(`
		ALTER TABLE IF EXISTS orders
		ALTER COLUMN IF EXISTS price TYPE double precision
		USING price::double precision;
	`).Error; err != nil {
		log.Println("WARN: could not alter orders.price type:", err)
	}
	if err := database.DB.AutoMigrate(&models.User{}, &models.Order{}); err != nil {
		log.Fatal("Migration failed:", err)
	}
	log.Println("Migrations completed successfully")

	log.Println("Running seed...")
	database.Seed()
	log.Println("Done.")
}
