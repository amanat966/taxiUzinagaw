package controllers

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"taxi-fleet-backend/database"
	"taxi-fleet-backend/models"
	"taxi-fleet-backend/utils"
	"time"

	"github.com/gin-gonic/gin"
)

type CreateOrderInput struct {
	FromAddress string `json:"from_address" binding:"required"`
	ToAddress   string `json:"to_address" binding:"required"`
	Comment     string `json:"comment"`
	Price       float64 `json:"price" binding:"required"`
	ClientName  string `json:"client_name" binding:"required"`
	ClientPhone string `json:"client_phone" binding:"required"`
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
		Price:       input.Price,
		ClientName:  input.ClientName,
		ClientPhone: input.ClientPhone,
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

	// Push notification (best-effort, async)
	go func(created models.Order) {
		serverKey := os.Getenv("FCM_SERVER_KEY")
		if serverKey == "" {
			return
		}
		var tokens []string

		if created.DriverID != nil {
			var driver models.User
			if err := database.DB.First(&driver, *created.DriverID).Error; err == nil && driver.FcmToken != "" {
				tokens = []string{driver.FcmToken}
			}
		} else {
			var drivers []models.User
			if err := database.DB.Where("role = ? AND fcm_token <> ''", models.RoleDriver).Find(&drivers).Error; err == nil {
				for _, d := range drivers {
					if d.FcmToken != "" {
						tokens = append(tokens, d.FcmToken)
					}
				}
			}
		}

		if len(tokens) == 0 {
			return
		}

		title := "Новый заказ"
		body := fmt.Sprintf("%s → %s, %.0f тг", created.FromAddress, created.ToAddress, created.Price)
		data := map[string]any{
			"type":        "new_order",
			"order_id":    created.ID,
			"from":        created.FromAddress,
			"to":          created.ToAddress,
			"price":       created.Price,
			"client_name": created.ClientName,
			"client_phone": created.ClientPhone,
		}
		if err := utils.SendFcmLegacyMulticast(serverKey, tokens, title, body, data); err != nil {
			log.Printf("FCM send error: %v", err)
		}
	}(order)

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
		// Drivers should see:
		// - orders assigned to them (assigned/accepted/in_progress)
		// - unassigned "new" orders (driver_id IS NULL) so any driver can accept
		if err := database.DB.
			Where(
				"(driver_id = ? AND status IN ?) OR (driver_id IS NULL AND status = ?)",
				userID,
				[]models.OrderStatus{models.OrderAssigned, models.OrderAccepted, models.OrderInProgress},
				models.OrderNew,
			).
			Order("created_at DESC").
			Find(&orders).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not fetch orders"})
			return
		}
	}

	c.JSON(http.StatusOK, orders)
}

// GetOrderHistory lists completed orders for current driver
func GetOrderHistory(c *gin.Context) {
	userID, _ := c.Get("userID")
	role, _ := c.Get("role")

	if role != string(models.RoleDriver) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden"})
		return
	}

	var orders []models.Order
	if err := database.DB.
		Where("driver_id = ? AND status = ?", userID, models.OrderDone).
		Order("updated_at DESC").
		Find(&orders).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not fetch history"})
		return
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
		switch input.Status {
		case models.OrderAccepted:
			// Driver can accept:
			// - an order assigned to them (status=assigned, driver_id=user)
			// - an unassigned new order (status=new, driver_id=NULL) -> claim it
			driverUID := userID.(uint)
			if order.Status == models.OrderAssigned {
				if order.DriverID == nil || *order.DriverID != driverUID {
					c.JSON(http.StatusForbidden, gin.H{"error": "Not your order"})
					return
				}
				order.Status = models.OrderAccepted
			} else if order.Status == models.OrderNew && order.DriverID == nil {
				// claim with a transaction to avoid double-accept
				tx := database.DB.Begin()
				if tx.Error != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not accept order"})
					return
				}
				res := tx.Model(&models.Order{}).
					Where("id = ? AND status = ? AND driver_id IS NULL", order.ID, models.OrderNew).
					Updates(map[string]any{
						"driver_id":  driverUID,
						"status":     models.OrderAccepted,
						"updated_at": time.Now(),
					})
				if res.Error != nil {
					tx.Rollback()
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not accept order"})
					return
				}
				if res.RowsAffected == 0 {
					tx.Rollback()
					c.JSON(http.StatusBadRequest, gin.H{"error": "Order already accepted"})
					return
				}
				if err := tx.Commit().Error; err != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not accept order"})
					return
				}
				// reload updated order
				if err := database.DB.First(&order, order.ID).Error; err == nil {
					c.JSON(http.StatusOK, order)
					return
				}
				c.JSON(http.StatusOK, order)
				return
			} else {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status transition"})
				return
			}
		case models.OrderInProgress:
			if order.DriverID == nil || *order.DriverID != userID.(uint) {
				c.JSON(http.StatusForbidden, gin.H{"error": "Not your order"})
				return
			}
			if order.Status == models.OrderAccepted {
				order.Status = models.OrderInProgress
				updateDriverStatus(*order.DriverID, models.StatusBusy)
			}
		case models.OrderDone:
			if order.DriverID == nil || *order.DriverID != userID.(uint) {
				c.JSON(http.StatusForbidden, gin.H{"error": "Not your order"})
				return
			}
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
