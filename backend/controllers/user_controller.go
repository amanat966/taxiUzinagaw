package controllers

import (
	"net/http"
	"taxi-fleet-backend/database"
	"taxi-fleet-backend/models"

	"github.com/gin-gonic/gin"
)

type CreateDriverInput struct {
	Name     string `json:"name" binding:"required"`
	Phone    string `json:"phone" binding:"required"`
	Password string `json:"password" binding:"required,min=6"`
}

// CreateDriver creates a new driver (Dispatcher only)
func CreateDriver(c *gin.Context) {
	var input CreateDriverInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := models.User{
		Name:         input.Name,
		Phone:        input.Phone,
		Role:         models.RoleDriver,
		DriverStatus: models.StatusOffline,
	}

	if err := user.SetPassword(input.Password); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not hash password"})
		return
	}

	if err := database.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Could not create driver, phone might be taken"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Driver created successfully",
		"user":    user,
	})
}

type ChangePasswordInput struct {
	OldPassword string `json:"old_password" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=6"`
}

// ChangePassword allows any authenticated user to change their password
func ChangePassword(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var input ChangePasswordInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if err := user.CheckPassword(input.OldPassword); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid current password"})
		return
	}

	if err := user.SetPassword(input.NewPassword); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not hash password"})
		return
	}

	if err := database.DB.Save(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not update password"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Password changed successfully"})
}
