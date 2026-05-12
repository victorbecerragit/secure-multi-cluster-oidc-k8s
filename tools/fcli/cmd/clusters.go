package cmd

import (
	"tools/fcli/internal/cache"
	"tools/fcli/internal/kube"

	"github.com/spf13/cobra"
)

var clustersCmd = &cobra.Command{
	Use:   "clusters",
	Short: "List allowed clusters",
	Run: func(cmd *cobra.Command, args []string) {
		_, err := cache.LoadToken()
		if err != nil {
			cmd.Println("Not logged in. Run 'fcli login'.")
			return
		}
		clusters, err := kube.ListClusters()
		if err != nil {
			cmd.Printf("Failed to list clusters: %v\n", err)
			return
		}
		if len(clusters) == 0 {
			cmd.Println("No clusters found in kubeconfig.")
			return
		}
		cmd.Println("Available clusters:")
		for _, c := range clusters {
			cmd.Printf("- %s\n", c)
		}
	},
}

func init() {
	rootCmd.AddCommand(clustersCmd)
}
