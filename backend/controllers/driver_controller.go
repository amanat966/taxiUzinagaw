package controllers

import (
	"net/http"
	"taxi-fleet-backend/database"
	"taxi-fleet-backend/models"

	"github.com/gin-gonic/gin"
)

// GetDrivers lists all drivers with their status and stats (Dispatcher only)
func GetDrivers(c *gin.Context) {
	var drivers []models.User
	if err := database.DB.Where("role = ?", models.RoleDriver).Find(&drivers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not fetch drivers"})
		return
	}
	type driverWithStats struct {
		ID                uint   `json:"id"`
		Name              string `json:"name"`
		Phone             string `json:"phone"`
		Role              string `json:"role"`
		DriverStatus      string `json:"driver_status"`
		AvatarURL         string `json:"avatar_url,omitempty"`
		CreatedAt         string `json:"created_at"`
		OrdersDone        int64  `json:"orders_done"`
		OrdersInProgress  int64  `json:"orders_in_progress"`
	}
	result := make([]driverWithStats, len(drivers))
	for i, d := range drivers {
		var done, inProgress int64
		database.DB.Model(&models.Order{}).Where("driver_id = ? AND status = ?", d.ID, models.OrderDone).Count(&done)
		database.DB.Model(&models.Order{}).Where("driver_id = ? AND status IN ?", d.ID, []models.OrderStatus{models.OrderAssigned, models.OrderAccepted, models.OrderInProgress}).Count(&inProgress)
		result[i] = driverWithStats{
			ID:               d.ID,
			Name:             d.Name,
			Phone:            d.Phone,
			Role:             string(d.Role),
			DriverStatus:     string(d.DriverStatus),
			AvatarURL:        d.AvatarURL,
			CreatedAt:        d.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
			OrdersDone:       done,
			OrdersInProgress: inProgress,
		}
	}
	c.JSON(http.StatusOK, result)
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
