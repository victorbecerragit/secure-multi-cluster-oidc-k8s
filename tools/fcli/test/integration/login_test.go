package integration

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"tools/fcli/internal/cache"
	"tools/fcli/internal/oidc"
)

func TestLogin(t *testing.T) {
	// This test requires a live Keycloak server and test credentials set in env vars.
	issuer := os.Getenv("FCLI_OIDC_ISSUER")
	clientID := os.Getenv("FCLI_OIDC_CLIENT_ID")
	if issuer == "" || clientID == "" {
		t.Skip("FCLI_OIDC_ISSUER or FCLI_OIDC_CLIENT_ID env vars not set; skipping integration test")
	}

	// Create a temporary directory for the token cache
	tempDir, err := os.MkdirTemp("", "fcli-test-cache-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir) // Clean up after the test

	// Override the token cache base directory for this test
	cache.SetTokenCacheBaseDir(tempDir)
	defer cache.SetTokenCacheBaseDir("") // Reset after test

	// 1. Perform OIDC login to get tokens
	oidcCfg := oidc.OIDCConfig{
		IssuerURL: issuer,
		ClientID:  clientID,
		Scopes:    []string{"openid", "profile", "email"},
	}
	oidcTok, err := oidc.DeviceCodeLogin(oidcCfg)
	if err != nil {
		t.Fatalf("Device code login failed: %v", err)
	}
	if oidcTok.AccessToken == "" {
		t.Fatal("OIDC login returned empty access token")
	}

	// 2. Simulate saving the token (as fcli login command would do)
	// The Expiry from oidc.OIDCToken is 'expires_in' (seconds), convert to absolute Unix timestamp for cache.Token
	cachedTok := &cache.Token{
		AccessToken:  oidcTok.AccessToken,
		RefreshToken: oidcTok.RefreshToken,
		IDToken:      oidcTok.IDToken,
		Expiry:       time.Now().Add(time.Duration(oidcTok.Expiry) * time.Second).Unix(),
	}
	if err := cache.SaveToken(cachedTok); err != nil {
		t.Fatalf("Failed to save token: %v", err)
	}

	// 3. Verify the token was saved correctly
	loadedTok, err := cache.LoadToken()
	if err != nil {
		t.Fatalf("Failed to load token after saving: %v", err)
	}
	if loadedTok.AccessToken != cachedTok.AccessToken {
		t.Errorf("Loaded access token mismatch. Expected %s, got %s", cachedTok.AccessToken, loadedTok.AccessToken)
	}
	t.Logf("Successfully logged in and cached token to %s", filepath.Join(tempDir, ".fcli", "token.json"))
}
