package controllers

import (
	"net/http"
	"taxi-fleet-backend/database"
	"taxi-fleet-backend/models"
	"taxi-fleet-backend/utils"

	"github.com/gin-gonic/gin"
)

type RegisterInput struct {
	Name     string      `json:"name" binding:"required"`
	Phone    string      `json:"phone" binding:"required"`
	Password string      `json:"password" binding:"required"`
	Role     models.Role `json:"role" binding:"required,oneof=dispatcher driver"`
}

type LoginInput struct {
	Phone    string `json:"phone" binding:"required"`
	Password string `json:"password" binding:"required"`
}

func Register(c *gin.Context) {
	var input RegisterInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := models.User{
		Name:  input.Name,
		Phone: input.Phone,
		Role:  input.Role,
	}

	if input.Role == models.RoleDriver {
		user.DriverStatus = models.StatusOffline
	}

	if err := user.SetPassword(input.Password); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not hash password"})
		return
	}

	if err := database.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Could not create user, phone might be taken"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "User created successfully"})
}

func Login(c *gin.Context) {
	var input LoginInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	if err := database.DB.Where("phone = ?", input.Phone).First(&user).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid phone or password"})
		return
	}

	if err := user.CheckPassword(input.Password); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid phone or password"})
		return
	}

	token, err := utils.GenerateToken(user.ID, string(user.Role))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not generate token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"token": token, "user": user})
}
