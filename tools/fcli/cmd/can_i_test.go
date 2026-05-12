package cmd

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"tools/fcli/internal/cache"
)

func TestBuildCanIArgsWithNamespace(t *testing.T) {
	args := buildCanIArgs("kind-manager", "get", "pods", "app-prod")
	joined := strings.Join(args, " ")
	want := "--context kind-manager auth can-i get pods -n app-prod"
	if joined != want {
		t.Fatalf("unexpected args. want %q, got %q", want, joined)
	}
}

func TestCanIRequiresLogin(t *testing.T) {
	tempDir := t.TempDir()
	cache.SetTokenCacheBaseDir(tempDir)
	defer cache.SetTokenCacheBaseDir("")

	buf := new(bytes.Buffer)
	canICmd.SetOut(buf)
	canICmd.SetErr(buf)

	canICmd.Run(canICmd, []string{"get", "pods"})

	if !strings.Contains(buf.String(), "Not logged in. Run 'fcli login'.") {
		t.Fatalf("expected not logged in message, got %q", buf.String())
	}
}

func TestCanINoSelectedContext(t *testing.T) {
	tempDir := t.TempDir()
	cache.SetTokenCacheBaseDir(tempDir)
	defer cache.SetTokenCacheBaseDir("")

	if err := cache.SaveToken(&cache.Token{AccessToken: "dummy"}); err != nil {
		t.Fatalf("failed to save token: %v", err)
	}

	kubeconfig := `apiVersion: v1
kind: Config
clusters: []
contexts: []
users: []
current-context: ""
`
	kubeconfigPath := filepath.Join(t.TempDir(), "config")
	if err := os.WriteFile(kubeconfigPath, []byte(kubeconfig), 0600); err != nil {
		t.Fatalf("failed to write kubeconfig: %v", err)
	}
	t.Setenv("KUBECONFIG", kubeconfigPath)

	buf := new(bytes.Buffer)
	canICmd.SetOut(buf)
	canICmd.SetErr(buf)

	canICmd.Run(canICmd, []string{"get", "pods"})

	if !strings.Contains(buf.String(), "No cluster is currently selected in kubeconfig") {
		t.Fatalf("expected no cluster selected message, got %q", buf.String())
	}
}

func TestCanIVerboseShowsCommand(t *testing.T) {
	tempDir := t.TempDir()
	cache.SetTokenCacheBaseDir(tempDir)
	defer cache.SetTokenCacheBaseDir("")

	if err := cache.SaveToken(&cache.Token{AccessToken: "dummy"}); err != nil {
		t.Fatalf("failed to save token: %v", err)
	}

	kubeconfig := `apiVersion: v1
kind: Config
clusters:
- name: kind-manager
  cluster:
    server: https://example
contexts:
- name: kind-manager
  context:
    cluster: kind-manager
    user: me
users:
- name: me
  user: {}
current-context: kind-manager
`
	kubeconfigPath := filepath.Join(t.TempDir(), "config")
	if err := os.WriteFile(kubeconfigPath, []byte(kubeconfig), 0600); err != nil {
		t.Fatalf("failed to write kubeconfig: %v", err)
	}
	t.Setenv("KUBECONFIG", kubeconfigPath)

	origNamespace := canINamespace
	origVerbose := canIVerbose
	origRunKubectl := runKubectl
	defer func() {
		canINamespace = origNamespace
		canIVerbose = origVerbose
		runKubectl = origRunKubectl
	}()

	canINamespace = "app-prod"
	canIVerbose = true
	runKubectl = func(args []string) (string, error) { return "yes", nil }

	buf := new(bytes.Buffer)
	canICmd.SetOut(buf)
	canICmd.SetErr(buf)

	canICmd.Run(canICmd, []string{"get", "pods"})

	output := buf.String()
	if !strings.Contains(output, "Executing: kubectl --context kind-manager auth can-i get pods -n app-prod") {
		t.Fatalf("expected verbose command output, got %q", output)
	}
	if !strings.Contains(output, "yes") {
		t.Fatalf("expected kubectl output, got %q", output)
	}
}
