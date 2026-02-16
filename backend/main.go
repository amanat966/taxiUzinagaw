package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-contrib/cors"
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

	// Seed initial admin if empty
	database.Seed()

	r := gin.New()
	r.Use(gin.Recovery())
	// Обработка OPTIONS ДО роутинга (httprouter не знает про OPTIONS)
	r.Use(func(c *gin.Context) {
		if c.Request.Method == "OPTIONS" {
			c.Header("Access-Control-Allow-Origin", "*")
			c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
			c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	})
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Content-Length", "Accept-Encoding", "Authorization"},
		AllowCredentials: false,
	}))
	r.Use(gin.Logger())

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

	// Auth routes requiring token
	authProtected := r.Group("/api/auth")
	authProtected.Use(middleware.AuthMiddleware())
	{
		authProtected.PUT("/change-password", controllers.ChangePassword)
	}

	// Protected Routes
	api := r.Group("/api")
	api.Use(middleware.AuthMiddleware())
	{
		// Driver Routes
		api.GET("/drivers", middleware.RoleMiddleware("dispatcher"), controllers.GetDrivers)
		api.POST("/drivers", middleware.RoleMiddleware("dispatcher"), controllers.CreateDriver)
		api.PUT("/drivers/status", middleware.RoleMiddleware("driver"), controllers.UpdateDriverStatus)

		// Order Routes
		api.POST("/orders", middleware.RoleMiddleware("dispatcher"), controllers.CreateOrder)
		api.GET("/orders", controllers.GetOrders)
		api.PUT("/orders/:id/assign", middleware.RoleMiddleware("dispatcher"), controllers.AssignDriver)
		api.PUT("/orders/:id/status", controllers.UpdateOrderStatus)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	r.Run(":" + port)
}
