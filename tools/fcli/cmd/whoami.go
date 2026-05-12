package cmd

import (
	"time"

	"tools/fcli/internal/cache"
	"tools/fcli/internal/oidc"

	"github.com/spf13/cobra"
)

var whoamiCmd = &cobra.Command{
	Use:   "whoami",
	Short: "Show the current OIDC identity",
	Run: func(cmd *cobra.Command, args []string) {
		tok, err := cache.LoadToken()
		if err != nil {
			cmd.Println("Not logged in. Run 'fcli login'.")
			return
		}

		// Parse the JWT token and extract claims
		claims, err := oidc.ParseTokenClaims(tok.AccessToken)
		if err != nil {
			cmd.Printf("Failed to parse access token: %v\n", err)
			return
		}

		// Check if token is expired and attempt refresh
		refreshedTok, err := oidc.RefreshAndSaveToken(cmd, tok)
		if err != nil {
			// RefreshAndSaveToken already prints user-friendly messages
			return
		}
		tok = refreshedTok // Use the potentially refreshed token

		// Re-parse claims from the (potentially) refreshed token
		claims, err = oidc.ParseTokenClaims(tok.AccessToken)
		if err != nil {
			cmd.Printf("Failed to parse access token after refresh attempt: %v\n", err)
			return
		}

		cmd.Println("Current OIDC Identity:")
		if sub, ok := claims["sub"].(string); ok {
			cmd.Printf("  Subject (User ID): %s\n", sub)
		}
		if name, ok := claims["name"].(string); ok { // Common claim for full name
			cmd.Printf("  Name: %s\n", name)
		}
		if email, ok := claims["email"].(string); ok { // Common claim for email
			cmd.Printf("  Email: %s\n", email)
		}
		if groups, ok := claims["groups"].([]interface{}); ok {
			cmd.Printf("  Groups: %v\n", groups)
		}
		if iss, ok := claims["iss"].(string); ok {
			cmd.Printf("  Issuer: %s\n", iss)
		}
		if exp, ok := claims["exp"].(float64); ok {
			expiryTime := time.Unix(int64(exp), 0)
			cmd.Printf("  Expires: %s (in %s)\n", expiryTime.Format(time.RFC1123), time.Until(expiryTime).Round(time.Second))
		}
	},
}

func init() {
	rootCmd.AddCommand(whoamiCmd)
}
