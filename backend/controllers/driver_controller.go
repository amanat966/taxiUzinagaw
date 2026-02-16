package controllers

import (
	"net/http"
	"taxi-fleet-backend/database"
	"taxi-fleet-backend/models"

	"github.com/gin-gonic/gin"
)

// GetDrivers lists all drivers with their status (Dispatcher only)
func GetDrivers(c *gin.Context) {
	var drivers []models.User
	if err := database.DB.Where("role = ?", models.RoleDriver).Find(&drivers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not fetch drivers"})
		return
	}
	c.JSON(http.StatusOK, drivers)
}

type UpdateDriverStatusInput struct {
	Status models.DriverStatus `json:"status" binding:"required,oneof=offline free busy"`
}

// UpdateDriverStatus updates the calling driver's status
func UpdateDriverStatus(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var input UpdateDriverStatusInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Update status
	user.DriverStatus = input.Status
	// Also manage status logic if needed (e.g. if going offline, check active orders?)
	// For MVP simplicity, just update.

	if err := database.DB.Save(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not update status"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Status updated", "status": user.DriverStatus})
}
