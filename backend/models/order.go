package models

import (
	"time"
)

type OrderStatus string

const (
	OrderNew        OrderStatus = "new"
	OrderAssigned   OrderStatus = "assigned"
	OrderAccepted   OrderStatus = "accepted"
	OrderInProgress OrderStatus = "in_progress"
	OrderDone       OrderStatus = "done"
	OrderCancelled  OrderStatus = "cancelled"
)

type Order struct {
	ID          uint        `gorm:"primaryKey" json:"id"`
	FromAddress string      `json:"from_address"`
	ToAddress   string      `json:"to_address"`
	Comment     string      `json:"comment"`
	DriverID    *uint       `json:"driver_id"`
	Driver      *User       `json:"driver,omitempty"`
	Status      OrderStatus `json:"status"`
	CreatedAt   time.Time   `json:"created_at"`
	UpdatedAt   time.Time   `json:"updated_at"`
}
