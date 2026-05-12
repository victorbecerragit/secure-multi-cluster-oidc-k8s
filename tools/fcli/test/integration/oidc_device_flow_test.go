//go:build integration
// +build integration

package integration

import (
	"os"
	"testing"
	"tools/fcli/internal/oidc"
)

// This test requires a live Keycloak server and test credentials set in env vars.
func TestDeviceCodeLogin(t *testing.T) {
	issuer := os.Getenv("FCLI_OIDC_ISSUER")
	clientID := os.Getenv("FCLI_OIDC_CLIENT_ID")
	if issuer == "" || clientID == "" {
		t.Skip("OIDC env vars not set; skipping integration test")
	}
	cfg := oidc.OIDCConfig{
		IssuerURL: issuer,
		ClientID:  clientID,
		Scopes:    []string{"openid", "profile", "email"},
	}
	tok, err := oidc.DeviceCodeLogin(cfg)
	if err != nil {
		t.Fatalf("Device code login failed: %v", err)
	}
	if tok.AccessToken == "" || tok.IDToken == "" {
		t.Error("Missing tokens in response")
	}
}
