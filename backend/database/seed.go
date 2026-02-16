package database

import (
	"log"
	"os"
	"taxi-fleet-backend/models"
)

// Seed creates initial data if database is empty
func Seed() {
	SeedAdmin()
}

// SeedAdmin ensures the default admin exists. Creates if not found by phone.
func SeedAdmin() {
	phone := os.Getenv("SEED_ADMIN_PHONE")
	if phone == "" {
		phone = "77000000000"
	}
	password := os.Getenv("SEED_ADMIN_PASSWORD")
	if password == "" {
		password = "admin123"
	}

	var existing models.User
	if err := DB.Where("phone = ?", phone).First(&existing).Error; err == nil {
		log.Printf("Seed: admin with phone %s already exists", phone)
		return
	}

	admin := models.User{
		Name:         "Administrator",
		Phone:        phone,
		Role:         models.RoleDispatcher,
		DriverStatus: models.StatusOffline,
	}
	if err := admin.SetPassword(password); err != nil {
		log.Printf("Seed: could not hash password: %v", err)
		return
	}
	if err := DB.Create(&admin).Error; err != nil {
		log.Printf("Seed: could not create admin: %v", err)
		return
	}
	log.Printf("Seed: created dispatcher (phone=%s, password=admin123). Change password on first login!", phone)
}
