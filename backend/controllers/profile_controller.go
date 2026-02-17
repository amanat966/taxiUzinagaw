package controllers

import (
	"encoding/base64"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"taxi-fleet-backend/database"
	"taxi-fleet-backend/models"
	"time"

	"github.com/gin-gonic/gin"
)

type UpdateProfileInput struct {
	Name         *string `json:"name"`
	Phone        *string `json:"phone"`
	AvatarBase64 *string `json:"avatar_base64"` // optional, may contain data URI prefix
}

func GetProfile(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var user models.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, user)
}

func UpdateProfile(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var input UpdateProfileInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if input.Name != nil {
		user.Name = strings.TrimSpace(*input.Name)
	}
	if input.Phone != nil {
		user.Phone = strings.TrimSpace(*input.Phone)
	}

	// Save avatar (best-effort)
	if input.AvatarBase64 != nil && strings.TrimSpace(*input.AvatarBase64) != "" {
		raw := strings.TrimSpace(*input.AvatarBase64)
		if idx := strings.Index(raw, "base64,"); idx != -1 {
			raw = raw[idx+len("base64,"):]
		}

		b, err := base64.StdEncoding.DecodeString(raw)
		if err == nil && len(b) > 0 {
			ext := ".png"
			// jpg magic
			if len(b) >= 2 && b[0] == 0xFF && b[1] == 0xD8 {
				ext = ".jpg"
			} else if len(b) >= 8 && string(b[:8]) == "\x89PNG\r\n\x1a\n" {
				ext = ".png"
			}

			_ = os.MkdirAll(filepath.Join("uploads", "avatars"), 0755)
			filename := filepath.Join("uploads", "avatars", strconv.FormatUint(uint64(user.ID), 10)+ext)
			if writeErr := os.WriteFile(filename, b, 0644); writeErr == nil {
				// Cache-busting via updated timestamp
				user.AvatarURL = "/static/avatars/" + strconv.FormatUint(uint64(user.ID), 10) + ext + "?t=" + strconv.FormatInt(time.Now().Unix(), 10)
			}
		}
	}

	if err := database.DB.Save(&user).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Could not update profile"})
		return
	}

	c.JSON(http.StatusOK, user)
}

