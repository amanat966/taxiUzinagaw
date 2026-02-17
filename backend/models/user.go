package models

import (
	"time"

	"golang.org/x/crypto/bcrypt"
)

type Role string
type DriverStatus string

const (
	RoleDispatcher Role = "dispatcher"
	RoleDriver     Role = "driver"

	StatusOffline DriverStatus = "offline"
	StatusFree    DriverStatus = "free"
	StatusBusy    DriverStatus = "busy"
)

type User struct {
	ID           uint         `gorm:"primaryKey" json:"id"`
	Name         string       `json:"name"`
	Phone        string       `gorm:"uniqueIndex" json:"phone"`
	Role         Role         `json:"role"`
	DriverStatus DriverStatus `json:"driver_status"` // Only for drivers
	AvatarURL    string       `json:"avatar_url,omitempty"` // URL фото (для будущей загрузки)
	FcmToken     string       `gorm:"column:fcm_token" json:"-"` // device token for push notifications
	PasswordHash string       `json:"-"`
	CreatedAt    time.Time    `json:"created_at"`
}

func (u *User) SetPassword(password string) error {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	u.PasswordHash = string(hashedPassword)
	return nil
}

func (u *User) CheckPassword(password string) error {
	return bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password))
}
