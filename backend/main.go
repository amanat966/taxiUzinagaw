package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"

	"taxi-fleet-backend/controllers"
	"taxi-fleet-backend/database"
	"taxi-fleet-backend/middleware"
	"taxi-fleet-backend/models"
)

func main() {
	// Load .env file
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found")
	}

	// Connect to Database
	database.Connect()

	// Auto Migrate
	err := database.DB.AutoMigrate(&models.User{}, &models.Order{})
	if err != nil {
		log.Fatal("Failed to migrate database:", err)
	}

	r := gin.Default()

	r.GET("/ping", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "pong",
		})
	})

	// Auth Routes
	auth := r.Group("/auth")
	{
		auth.POST("/register", controllers.Register)
		auth.POST("/login", controllers.Login)
	}

	// Protected Routes
	api := r.Group("/api")
	api.Use(middleware.AuthMiddleware())
	{
		// Driver Routes
		api.GET("/drivers", middleware.RoleMiddleware("dispatcher"), controllers.GetDrivers)
		api.PUT("/drivers/status", middleware.RoleMiddleware("driver"), controllers.UpdateDriverStatus)

		// Order Routes
		api.POST("/orders", middleware.RoleMiddleware("dispatcher"), controllers.CreateOrder)
		api.GET("/orders", controllers.GetOrders) // Both can view, filtered by role in controller
		api.PUT("/orders/:id/status", controllers.UpdateOrderStatus)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	r.Run(":" + port)
}
