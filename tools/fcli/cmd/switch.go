package cmd

import (
	"tools/fcli/internal/cache"
	"tools/fcli/internal/kube"

	"github.com/spf13/cobra"
)

var switchCmd = &cobra.Command{
	Use:   "switch [CLUSTER]",
	Short: "Switch current context to a cluster",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		_, err := cache.LoadToken()
		if err != nil {
			cmd.Println("Not logged in. Run 'fcli login'.")
			return
		}
		cluster := args[0]
		if err := kube.SwitchContext(cluster); err != nil {
			cmd.Printf("Failed to switch context: %v\n", err)
			return
		}
		cmd.Printf("Switched context to '%s'\n", cluster)
	},
}

func init() {
	rootCmd.AddCommand(switchCmd)
}
