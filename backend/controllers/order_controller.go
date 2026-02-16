package controllers

import (
	"log"
	"net/http"
	"strconv"
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
		if err := database.DB.Preload("Driver").Where("status NOT IN ?", []models.OrderStatus{models.OrderDone, models.OrderCancelled}).Find(&orders).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not fetch orders"})
			return
		}
	} else if role == string(models.RoleDriver) {
		if err := database.DB.Where("driver_id = ? AND status IN ?", userID, []models.OrderStatus{models.OrderAssigned, models.OrderAccepted, models.OrderInProgress}).Find(&orders).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not fetch orders"})
			return
		}
	}

	c.JSON(http.StatusOK, orders)
}

type AssignDriverInput struct {
	DriverID uint `json:"driver_id" binding:"required"`
}

// AssignDriver assigns a driver to an order (Dispatcher only)
func AssignDriver(c *gin.Context) {
	idParam := c.Param("id")
	log.Printf("AssignDriver called with order ID: %s", idParam)
	
	var input AssignDriverInput
	if err := c.ShouldBindJSON(&input); err != nil {
		log.Printf("Error binding JSON: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	log.Printf("AssignDriver: driver_id=%d, order_id=%s", input.DriverID, idParam)

	// Convert string ID to uint for GORM query
	idInt, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		log.Printf("Error parsing order ID: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid order ID format"})
		return
	}
	id := uint(idInt)

	var order models.Order
	if err := database.DB.First(&order, id).Error; err != nil {
		log.Printf("Order not found: ID=%d, error=%v", id, err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}
	
	log.Printf("Order found: ID=%d, Status=%s", order.ID, order.Status)

	if order.Status == models.OrderCancelled || order.Status == models.OrderDone {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot assign driver to completed or cancelled order"})
		return
	}

	var driver models.User
	if err := database.DB.First(&driver, input.DriverID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver not found"})
		return
	}
	if driver.Role != models.RoleDriver {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User is not a driver"})
		return
	}

	order.DriverID = &input.DriverID
	order.Status = models.OrderAssigned
	order.UpdatedAt = time.Now()

	if err := database.DB.Save(&order).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not assign driver"})
		return
	}

	database.DB.Preload("Driver").First(&order, order.ID)
	c.JSON(http.StatusOK, order)
}

type UpdateOrderStatusInput struct {
	Status models.OrderStatus `json:"status" binding:"required"`
}

// UpdateOrderStatus handles status transitions
func UpdateOrderStatus(c *gin.Context) {
	idParam := c.Param("id")
	var input UpdateOrderStatusInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Convert string ID to uint for GORM query
	idInt, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid order ID format"})
		return
	}
	id := uint(idInt)

	var order models.Order
	if err := database.DB.First(&order, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	role, _ := c.Get("role")
	userID, _ := c.Get("userID")

	updateDriverStatus := func(driverID uint, status models.DriverStatus) {
		var driver models.User
		if err := database.DB.First(&driver, driverID).Error; err == nil {
			driver.DriverStatus = status
			database.DB.Save(&driver)
		}
	}

	if role == string(models.RoleDispatcher) {
		if input.Status == models.OrderCancelled {
			order.Status = models.OrderCancelled
			if order.DriverID != nil {
				updateDriverStatus(*order.DriverID, models.StatusFree)
			}
		} else {
			order.Status = input.Status
		}
	} else {
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
				updateDriverStatus(*order.DriverID, models.StatusFree)
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
