package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// SendFcmLegacyMulticast sends a push notification via FCM Legacy HTTP API.
// serverKey should be provided via env (FCM_SERVER_KEY).
// tokens must be non-empty.
func SendFcmLegacyMulticast(serverKey string, tokens []string, title string, body string, data map[string]any) error {
	if serverKey == "" {
		return fmt.Errorf("missing FCM_SERVER_KEY")
	}
	if len(tokens) == 0 {
		return nil
	}

	payload := map[string]any{
		"registration_ids": tokens,
		"notification": map[string]any{
			"title": title,
			"body":  body,
		},
		"data": data,
	}

	b, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequest(http.MethodPost, "https://fcm.googleapis.com/fcm/send", bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "key="+serverKey)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("fcm error status=%d", resp.StatusCode)
	}
	return nil
}

