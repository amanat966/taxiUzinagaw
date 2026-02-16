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
	if err := database.DB.AutoMigrate(&models.User{}, &models.Order{}); err != nil {
		log.Fatal("Migration failed:", err)
	}
	log.Println("Migrations completed successfully")

	log.Println("Running seed...")
	database.Seed()
	log.Println("Done.")
}
