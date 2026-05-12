package cmd

import (
	"time"

	"tools/fcli/internal/cache"
	"tools/fcli/internal/kube"
	"tools/fcli/internal/oidc"

	"github.com/spf13/cobra"
)

var validateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Validate current OIDC/Kube access",
	Run: func(cmd *cobra.Command, args []string) {
		tok, err := cache.LoadToken()
		if err != nil {
			cmd.Println("Not logged in. Run 'fcli login'.")
			return
		}

		cmd.Println("Validating OIDC token and Kubernetes access...")

		// 1. Validate OIDC Token
		cmd.Println("  - Validating OIDC token...")
		claims, err := oidc.ParseTokenClaims(tok.AccessToken)
		if err != nil {
			cmd.Printf("    ❌ Failed to parse access token: %v\n", err)
			return
		}

		// Attempt to refresh token if expired
		refreshedTok, err := oidc.RefreshAndSaveToken(cmd, tok)
		if err != nil {
			// RefreshAndSaveToken already prints user-friendly messages
			return
		}
		tok = refreshedTok // Use the potentially refreshed token

		// Re-parse claims from the (potentially) refreshed token to get its updated expiry
		claims, err = oidc.ParseTokenClaims(tok.AccessToken)
		if err != nil {
			cmd.Printf("    ❌ Failed to parse access token after refresh attempt: %v\n", err)
			return
		}

		if exp, ok := claims["exp"].(float64); ok { // Check expiry again with potentially new token
			expiryTime := time.Unix(int64(exp), 0)
			cmd.Printf("    ✅ OIDC token is valid (expires in %s).\n", time.Until(expiryTime).Round(time.Second))
		} else {
			cmd.Println("    ⚠️ Could not determine token expiration from claims.")
		}

		// 2. Validate Kubernetes API Connectivity and Basic RBAC
		cmd.Println("  - Validating Kubernetes API connectivity and basic RBAC...")
		kubeClient, err := kube.GetKubeClient(tok.AccessToken)
		if err != nil {
			cmd.Printf("    ❌ Failed to get Kubernetes client: %v\n", err)
			return
		}

		if err := kube.ValidateConnectivity(kubeClient); err != nil {
			cmd.Printf("    ❌ Failed to list namespaces (Kubernetes API access denied or connectivity issue): %v\n", err)
			cmd.Println("       This could indicate an RBAC issue or a problem reaching the cluster.")
			return
		}
		cmd.Println("    ✅ Successfully connected to Kubernetes API and listed namespaces.")
		cmd.Println("Validation successful!")
	},
}

func init() {
	rootCmd.AddCommand(validateCmd)
}
