package cmd

import (
	"os"
	"tools/fcli/internal/cache"
	"tools/fcli/internal/oidc"

	"github.com/spf13/cobra"
)

var loginCmd = &cobra.Command{
	Use:   "login",
	Short: "Authenticate via OIDC (Keycloak)",
	Run: func(cmd *cobra.Command, args []string) {
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

		if issuer == "" || clientID == "" {
			cmd.PrintErrln("OIDC login failed: missing OIDC configuration.")
			cmd.Println("Set FCLI_OIDC_ISSUER and FCLI_OIDC_CLIENT_ID, or run login once with them set to cache defaults.")
			return
		}

		cfg := oidc.OIDCConfig{
			IssuerURL: issuer,
			ClientID:  clientID,
			Scopes:    []string{"openid", "profile", "email"},
		}
		tok, err := oidc.DeviceCodeLogin(cfg)
		if err != nil {
			cmd.PrintErrln("OIDC login failed:", err)
			cmd.Println("\nTo log in manually, see README for device code instructions.")
			return
		}
		t := &cache.Token{
			AccessToken:  tok.AccessToken,
			RefreshToken: tok.RefreshToken,
			IDToken:      tok.IDToken,
			Expiry:       tok.Expiry, // tok.Expiry is now an absolute Unix timestamp
		}
		if err := cache.SaveToken(t); err != nil {
			cmd.PrintErrln("Failed to save token:", err)
			return
		}

		if err := cache.SaveOIDCConfig(&cache.OIDCConfig{IssuerURL: issuer, ClientID: clientID}); err != nil {
			cmd.Printf("Warning: login succeeded but failed to cache OIDC config: %v\n", err)
		}
		cmd.Println("Login successful. Token cached.")
	},
}

func init() {
	rootCmd.AddCommand(loginCmd)
}
