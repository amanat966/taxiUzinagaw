package controllers

import (
	"net/http"
	"taxi-fleet-backend/database"
	"taxi-fleet-backend/models"
	"time"

	"github.com/gin-gonic/gin"
)

type CreateOrderInput struct {
	FromAddress string `json:"from_address" binding:"required"`
	ToAddress   string `json:"to_address" binding:"required"`
	Comment     string `json:"comment"`
	DriverID    *uint  `json:"driver_id"` // Optional, can be assigned later
}

// CreateOrder (Dispatcher only)
func CreateOrder(c *gin.Context) {
	var input CreateOrderInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	order := models.Order{
		FromAddress: input.FromAddress,
		ToAddress:   input.ToAddress,
		Comment:     input.Comment,
		Status:      models.OrderNew,
		DriverID:    input.DriverID,
	}

	if input.DriverID != nil {
		order.Status = models.OrderAssigned
		// Ideally check if driver exists and is not busy?
		// For MVP, just assign.
	}

	if err := database.DB.Create(&order).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not create order"})
		return
	}

	c.JSON(http.StatusOK, order)
}

// GetOrders lists orders based on role
func GetOrders(c *gin.Context) {
	userID, _ := c.Get("userID")
	role, _ := c.Get("role")

	var orders []models.Order

	if role == string(models.RoleDispatcher) {
		// Dispatcher sees all active orders (not done/cancelled)
		// Or maybe all orders? Let's show active for now + new
		if err := database.DB.Preload("Driver").Where("status NOT IN ?", []models.OrderStatus{models.OrderDone, models.OrderCancelled}).Find(&orders).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not fetch orders"})
			return
		}
	} else if role == string(models.RoleDriver) {
		// Driver sees their assigned or active orders
		if err := database.DB.Where("driver_id = ? AND status IN ?", userID, []models.OrderStatus{models.OrderAssigned, models.OrderAccepted, models.OrderInProgress}).Find(&orders).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not fetch orders"})
			return
		}
	}

	c.JSON(http.StatusOK, orders)
}

type UpdateOrderStatusInput struct {
	Status models.OrderStatus `json:"status" binding:"required"`
}

// UpdateOrderStatus handles status transitions
func UpdateOrderStatus(c *gin.Context) {
	id := c.Param("id")
	var input UpdateOrderStatusInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var order models.Order
	if err := database.DB.First(&order, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	role, _ := c.Get("role")
	userID, _ := c.Get("userID")

	// Helper to update driver status based on order
	updateDriverStatus := func(driverID uint, status models.DriverStatus) {
		var driver models.User
		if err := database.DB.First(&driver, driverID).Error; err == nil {
			driver.DriverStatus = status
			database.DB.Save(&driver)
		}
	}

	if role == string(models.RoleDispatcher) {
		// Dispatcher can Cancel or Reassign (logic for reassign separate usually)
		// For now allow Dispatcher to set any status, primarily for Cancel
		if input.Status == models.OrderCancelled {
			order.Status = models.OrderCancelled
			if order.DriverID != nil {
				updateDriverStatus(*order.DriverID, models.StatusFree) // Or check queue? MVP: Free
			}
		} else {
			// Dispatcher assigning driver? mostly done via update with driver_id
			order.Status = input.Status
		}
	} else {
		// Driver transitions
		if order.DriverID == nil || *order.DriverID != userID.(uint) {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not your order"})
			return
		}

		switch input.Status {
		case models.OrderAccepted:
			if order.Status == models.OrderAssigned {
				order.Status = models.OrderAccepted
			}
		case models.OrderInProgress:
			if order.Status == models.OrderAccepted {
				order.Status = models.OrderInProgress
				updateDriverStatus(*order.DriverID, models.StatusBusy)
			}
		case models.OrderDone:
			if order.Status == models.OrderInProgress {
				order.Status = models.OrderDone
				// Check queue? MVP: set Free
				updateDriverStatus(*order.DriverID, models.StatusFree)
				// TODO: In real app, check if next assigned order exists
			}
		default:
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status transition"})
			return
		}
	}

	order.UpdatedAt = time.Now()
	if err := database.DB.Save(&order).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not update order"})
		return
	}

	c.JSON(http.StatusOK, order)
}
