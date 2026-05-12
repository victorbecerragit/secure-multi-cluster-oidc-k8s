package cmd

import (
	"os/exec"
	"strings"

	"tools/fcli/internal/cache"
	"tools/fcli/internal/kube"

	"github.com/spf13/cobra"
)

var canINamespace string
var canIVerbose bool

var runKubectl = func(args []string) (string, error) {
	cmd := exec.Command("kubectl", args...)
	out, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

func buildCanIArgs(currentContext, verb, resource, namespace string) []string {
	args := []string{"--context", currentContext, "auth", "can-i", verb, resource}
	if namespace != "" {
		args = append(args, "-n", namespace)
	}
	return args
}

var canICmd = &cobra.Command{
	Use:   "can-i [VERB] [RESOURCE]",
	Short: "Check whether the current identity can perform an action",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		if _, err := cache.LoadToken(); err != nil {
			cmd.Println("Not logged in. Run 'fcli login'.")
			return
		}

		currentContext, err := kube.CurrentContextName()
		if err != nil {
			cmd.Printf("Failed to read kubeconfig context: %v\n", err)
			return
		}
		if strings.TrimSpace(currentContext) == "" {
			cmd.Println("No cluster is currently selected in kubeconfig. Use 'fcli use <cluster>' first.")
			return
		}

		verb := args[0]
		resource := args[1]
		kubectlArgs := buildCanIArgs(currentContext, verb, resource, canINamespace)

		if canIVerbose {
			cmd.Println("Executing: kubectl " + strings.Join(kubectlArgs, " "))
		}

		out, err := runKubectl(kubectlArgs)
		if err != nil {
			if out != "" {
				cmd.Printf("kubectl auth can-i failed: %v\nOutput: %s\n", err, out)
			} else {
				cmd.Printf("kubectl auth can-i failed: %v\n", err)
			}
			return
		}

		if out == "" {
			cmd.Println("kubectl auth can-i returned no output")
			return
		}

		cmd.Println(out)
	},
}

func init() {
	canICmd.Flags().StringVarP(&canINamespace, "namespace", "n", "", "Namespace for the authorization check")
	canICmd.Flags().BoolVarP(&canIVerbose, "verbose", "v", false, "Show the exact kubectl command being executed")
	rootCmd.AddCommand(canICmd)
}
