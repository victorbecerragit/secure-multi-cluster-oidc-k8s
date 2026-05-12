package oidc

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"time"
	"tools/fcli/internal/cache"

	"github.com/golang-jwt/jwt/v5"
	"github.com/spf13/cobra"
)

type OIDCConfig struct {
	IssuerURL string
	ClientID  string
	Scopes    []string
}

type OIDCToken struct {
	AccessToken  string
	RefreshToken string
	IDToken      string
	// Expiry is the absolute Unix timestamp when the AccessToken expires.
	// This is calculated from the 'expires_in' duration received from the OIDC provider.
	Expiry int64
}

// DeviceCodeLogin performs OIDC device code flow and returns tokens.
func DeviceCodeLogin(cfg OIDCConfig) (*OIDCToken, error) {
	ctx := context.Background()
	// provider, err := oidc.NewProvider(ctx, cfg.IssuerURL)
	// if err != nil {
	//     return nil, fmt.Errorf("failed to get OIDC provider: %w", err)
	// }

	deviceAuthEndpoint := cfg.IssuerURL + "/protocol/openid-connect/auth/device"
	deviceTokenEndpoint := cfg.IssuerURL + "/protocol/openid-connect/token"

	// Step 1: Get device code
	type deviceCodeResp struct {
		DeviceCode              string `json:"device_code"`
		UserCode                string `json:"user_code"`
		VerificationURI         string `json:"verification_uri"`
		VerificationURIComplete string `json:"verification_uri_complete"`
		ExpiresIn               int    `json:"expires_in"`
		Interval                int    `json:"interval"`
	}
	form := make(map[string]string)
	form["client_id"] = cfg.ClientID
	form["scope"] = "openid profile email"

	resp, status, err := postFormWithStatus(deviceAuthEndpoint, form)
	if err != nil {
		return nil, fmt.Errorf("device code request failed: %w", err)
	}
	if status < 200 || status >= 300 {
		return nil, fmt.Errorf("device code request failed: HTTP %d", status)
	}
	defer resp.(io.ReadCloser).Close()
	var dc deviceCodeResp
	if err := decodeJSON(resp, &dc); err != nil {
		return nil, fmt.Errorf("decode device code: %w", err)
	}

	fmt.Printf("\nTo authenticate, visit: %s\nEnter code: %s\n\nOr open: %s\n", dc.VerificationURI, dc.UserCode, dc.VerificationURIComplete)

	// Step 2: Poll for token
	type tokenResp struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		IDToken      string `json:"id_token"`
		ExpiresIn    int64  `json:"expires_in"`
		Error        string `json:"error"`
		ErrorDesc    string `json:"error_description"`
	}

	interval := dc.Interval
	if interval == 0 {
		interval = 5
	}

	for {
		form2 := make(map[string]string)
		form2["grant_type"] = "urn:ietf:params:oauth:grant-type:device_code"
		form2["device_code"] = dc.DeviceCode
		form2["client_id"] = cfg.ClientID

		resp2, _, err := postFormWithStatus(deviceTokenEndpoint, form2)
		if err != nil {
			return nil, fmt.Errorf("token poll failed: %w", err)
		}
		defer resp2.(io.ReadCloser).Close()
		var tr tokenResp
		if err := decodeJSON(resp2, &tr); err != nil {
			return nil, fmt.Errorf("decode token: %w", err)
		}
		if tr.Error != "" {
			if tr.Error == "authorization_pending" {
				// keep polling
				select {
				case <-ctx.Done():
					return nil, ctx.Err()
				case <-sleepSec(interval):
					continue
				}
			}
			return nil, fmt.Errorf("device code error: %s (%s)", tr.Error, tr.ErrorDesc)
		}
		if tr.AccessToken != "" {
			return &OIDCToken{
				AccessToken:  tr.AccessToken,
				RefreshToken: tr.RefreshToken,
				IDToken:      tr.IDToken,
				Expiry:       time.Now().Add(time.Duration(tr.ExpiresIn) * time.Second).Unix(), // Calculate absolute expiry
			}, nil
		}
		// Defensive: avoid tight loop
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-sleepSec(interval):
		}
	}
}

// RefreshToken attempts to refresh an expired OIDC access token using the refresh token.
// It returns a new OIDCToken with updated access, ID, and potentially refresh tokens,
// along with the new absolute expiry time.
func RefreshToken(cfg OIDCConfig, currentRefreshToken string) (*OIDCToken, error) {
	if currentRefreshToken == "" {
		return nil, errors.New("no refresh token available to perform refresh")
	}

	tokenEndpoint := cfg.IssuerURL + "/protocol/openid-connect/token"

	form := make(map[string]string)
	form["grant_type"] = "refresh_token"
	form["client_id"] = cfg.ClientID
	form["refresh_token"] = currentRefreshToken
	// Ensure scopes are re-requested, as some providers require it for refresh
	form["scope"] = "openid profile email"

	resp, _, err := postFormWithStatus(tokenEndpoint, form)
	if err != nil {
		return nil, fmt.Errorf("refresh token request failed: %w", err)
	}
	defer resp.(io.ReadCloser).Close()

	type tokenResp struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"` // May be updated or remain the same
		IDToken      string `json:"id_token"`
		ExpiresIn    int64  `json:"expires_in"` // Duration in seconds
		Error        string `json:"error"`
		ErrorDesc    string `json:"error_description"`
	}
	var tr tokenResp
	if err := decodeJSON(resp, &tr); err != nil {
		return nil, fmt.Errorf("decode refresh token response: %w", err)
	}

	if tr.Error != "" {
		return nil, fmt.Errorf("refresh token error: %s (%s)", tr.Error, tr.ErrorDesc)
	}
	if tr.AccessToken == "" {
		return nil, errors.New("refresh token response did not contain an access token")
	}

	// If the OIDC provider issues a new refresh token, use it; otherwise, keep the old one.
	newRefreshToken := tr.RefreshToken
	if newRefreshToken == "" {
		newRefreshToken = currentRefreshToken
	}

	return &OIDCToken{
		AccessToken:  tr.AccessToken,
		RefreshToken: newRefreshToken,
		IDToken:      tr.IDToken,
		Expiry:       time.Now().Add(time.Duration(tr.ExpiresIn) * time.Second).Unix(), // Calculate absolute expiry
	}, nil
}

// --- helpers ---

func postFormWithStatus(targetURL string, data map[string]string) (io.Reader, int, error) {
	values := url.Values{}
	for k, v := range data {
		values.Set(k, v)
	}
	resp, err := http.PostForm(targetURL, values)
	if err != nil {
		return nil, 0, err
	}
	return resp.Body, resp.StatusCode, nil
}

// RefreshAndSaveToken checks if the provided token is expired. If so, it attempts to refresh it,
// updates the cached token, and returns the new token. It prints messages to the user via the cmd.
// If the token is not expired, or if expiry cannot be determined, the original token is returned.
func RefreshAndSaveToken(cmd *cobra.Command, tok *cache.Token) (*cache.Token, error) {
	claims, err := ParseTokenClaims(tok.AccessToken)
	if err != nil {
		return nil, fmt.Errorf("failed to parse access token for refresh check: %w", err)
	}

	exp, ok := claims["exp"].(float64)
	if !ok {
		cmd.Println("    ⚠️ Could not determine token expiration from claims. Skipping refresh check.")
		return tok, nil // Cannot determine expiry, assume valid for now and return original token
	}

	expiryTime := time.Unix(int64(exp), 0)
	if time.Now().Before(expiryTime) {
		// Token is not expired, no need to refresh
		return tok, nil
	}

	cmd.Printf("    ⚠️ OIDC token is expired (expired %s ago). Attempting to refresh...\n", time.Since(expiryTime).Round(time.Second))

	oidcCfg := resolveOIDCConfig(claims)
	if oidcCfg.IssuerURL == "" || oidcCfg.ClientID == "" {
		cmd.Println("    ❌ Missing OIDC issuer/client configuration for token refresh.")
		cmd.Println("       Set FCLI_OIDC_ISSUER and FCLI_OIDC_CLIENT_ID, then run 'fcli login' once to cache them.")
		return nil, errors.New("missing OIDC configuration")
	}

	newTok, refreshErr := RefreshToken(oidcCfg, tok.RefreshToken)
	if refreshErr != nil {
		cmd.Printf("    ❌ Failed to refresh token: %v\n", refreshErr)
		cmd.Println("       Please run 'fcli login' again.")
		return nil, refreshErr // Return error to indicate failure
	}

	// Update the cached token with the new one
	updatedTok := &cache.Token{AccessToken: newTok.AccessToken, RefreshToken: newTok.RefreshToken, IDToken: newTok.IDToken, Expiry: newTok.Expiry}
	if err := cache.SaveToken(updatedTok); err != nil {
		cmd.Printf("    ❌ Failed to save refreshed token: %v\n", err)
		return nil, err
	}
	cmd.Println("    ✅ OIDC token refreshed successfully.")

	return updatedTok, nil
}

func resolveOIDCConfig(claims jwt.MapClaims) OIDCConfig {
	issuer := os.Getenv("FCLI_OIDC_ISSUER")
	clientID := os.Getenv("FCLI_OIDC_CLIENT_ID")

	if issuer == "" || clientID == "" {
		if cachedCfg, err := cache.LoadOIDCConfig(); err == nil {
			if issuer == "" {
				issuer = cachedCfg.IssuerURL
			}
			if clientID == "" {
				clientID = cachedCfg.ClientID
			}
		}
	}

	if issuer == "" {
		if iss, ok := claims["iss"].(string); ok {
			issuer = iss
		}
	}

	if clientID == "" {
		if azp, ok := claims["azp"].(string); ok {
			clientID = azp
		} else if aud, ok := claims["aud"].(string); ok {
			clientID = aud
		}
	}

	return OIDCConfig{
		IssuerURL: issuer,
		ClientID:  clientID,
		Scopes:    []string{"openid", "profile", "email"},
	}
}

func decodeJSON(r io.Reader, v interface{}) error {
	return json.NewDecoder(r).Decode(v)
}

func sleepSec(sec int) <-chan time.Time {
	return time.After(time.Duration(sec) * time.Second)
}

// ParseTokenClaims parses an OIDC access token (JWT) and returns its claims.
// It does not perform signature verification, which is suitable for displaying
// token contents to the user or for initial validation of structure.
func ParseTokenClaims(accessToken string) (jwt.MapClaims, error) {
	parser := jwt.NewParser()
	claims := jwt.MapClaims{}
	_, _, err := parser.ParseUnverified(accessToken, claims)
	if err != nil {
		return nil, fmt.Errorf("failed to parse access token: %w", err)
	}
	return claims, nil
}
