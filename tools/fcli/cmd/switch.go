package cmd

import "github.com/spf13/cobra"

var switchCmd = &cobra.Command{
	Use:        "switch [CLUSTER]",
	Short:      "Switch current context to a cluster (alias for use)",
	Deprecated: "use 'fcli use' instead",
	Args:       cobra.ExactArgs(1),
	Run:        runUse,
}

func init() {
	rootCmd.AddCommand(switchCmd)
}
