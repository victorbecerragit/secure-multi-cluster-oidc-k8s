package cmd

import (
	"fmt"

	"tools/fcli/internal/cache"
	"tools/fcli/internal/kube"

	"github.com/spf13/cobra"
)

func runUse(cmd *cobra.Command, args []string) {
	tok, err := cache.LoadToken()
	if err != nil {
		cmd.Println("Not logged in. Run 'fcli login'.")
		return
	}

	selection := args[0]
	result, err := kube.UseContext(selection, tok.AccessToken)
	if err != nil {
		cmd.Printf("Failed to switch context: %v\n", err)
		return
	}

	cmd.Printf("Current context: %s\n", result.CurrentContext)
	cmd.Printf("Target context:  %s\n", result.TargetContext)
	if result.CurrentContext == result.TargetContext {
		cmd.Println("Context unchanged.")
		return
	}
	cmd.Println("Context updated successfully.")
}

var useCmd = &cobra.Command{
	Use:   "use [CLUSTER|CONTEXT]",
	Short: "Switch current kubeconfig context",
	Long: fmt.Sprintf("Switches current-context using a logical cluster name or explicit context.\n" +
		"Logical names supported: manager -> kind-manager, workload -> kind-workload."),
	Args: cobra.ExactArgs(1),
	Run:  runUse,
}

func init() {
	rootCmd.AddCommand(useCmd)
}
