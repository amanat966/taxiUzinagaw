package middleware

import (
	"log"
	"net/http"
	"strings"
	"taxi-fleet-backend/utils"

	"github.com/gin-gonic/gin"
)

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		log.Printf("AuthMiddleware: Method=%s, Path=%s", c.Request.Method, c.Request.URL.Path)
		const prefix = "Bearer "
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, prefix) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
			c.Abort()
			return
		}

		tokenString := authHeader[len(prefix):]
		claims, err := utils.ValidateToken(tokenString)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		c.Set("userID", claims.UserID)
		c.Set("role", claims.Role)
		c.Next()
	}
}

func RoleMiddleware(allowedRoles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		log.Printf("RoleMiddleware: Method=%s, Path=%s, AllowedRoles=%v", c.Request.Method, c.Request.URL.Path, allowedRoles)
		role, exists := c.Get("role")
		if !exists {
			log.Printf("RoleMiddleware: Role not found in context")
			c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden"})
			c.Abort()
			return
		}

		userRole := role.(string)
		log.Printf("RoleMiddleware: UserRole=%s", userRole)
		for _, allowed := range allowedRoles {
			if userRole == allowed {
				log.Printf("RoleMiddleware: Access granted")
				c.Next()
				return
			}
		}

		log.Printf("RoleMiddleware: Access denied")
		c.JSON(http.StatusForbidden, gin.H{"error": "Access denied"})
		c.Abort()
	}
}
