package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "fcli",
	Short: "Secure multi-cluster K8s CLI",
	Long:  `A minimal CLI for secure, user-friendly access to multiple Kubernetes clusters using OIDC and RBAC.`,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
