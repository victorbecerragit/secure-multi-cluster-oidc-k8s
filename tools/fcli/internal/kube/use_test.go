package kube

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

func writeTestKubeconfig(t *testing.T, path string) {
	t.Helper()
	content := `apiVersion: v1
kind: Config
clusters:
- name: kind-manager
  cluster:
    server: https://manager.example
- name: kind-workload
  cluster:
    server: https://workload.example
contexts:
- name: kind-manager
  context:
    cluster: kind-manager
    user: oidc-user
- name: kind-workload
  context:
    cluster: kind-workload
    user: oidc-user
users:
- name: oidc-user
  user:
    token: test
current-context: kind-workload
`
	if err := os.WriteFile(path, []byte(content), 0600); err != nil {
		t.Fatalf("failed to write kubeconfig: %v", err)
	}
}

func TestResolveContextNameLogicalAlias(t *testing.T) {
	cfg := clientcmdapi.NewConfig()
	cfg.Contexts["kind-manager"] = &clientcmdapi.Context{Cluster: "kind-manager", AuthInfo: "u"}
	cfg.Contexts["kind-workload"] = &clientcmdapi.Context{Cluster: "kind-workload", AuthInfo: "u"}

	target, err := resolveContextName(cfg, "manager")
	if err != nil {
		t.Fatalf("resolveContextName returned error: %v", err)
	}
	if target != "kind-manager" {
		t.Fatalf("expected kind-manager, got %s", target)
	}
}

func TestUseContextRejectsUnauthorizedWithoutWriting(t *testing.T) {
	tempDir := t.TempDir()
	kubeconfigPath := filepath.Join(tempDir, "config")
	writeTestKubeconfig(t, kubeconfigPath)

	original := mustReadFile(t, kubeconfigPath)
	t.Setenv("KUBECONFIG", kubeconfigPath)

	originalAuthorizer := authorizeContextSelection
	authorizeContextSelection = func(targetContext, token string) error {
		return errors.New("forbidden")
	}
	defer func() { authorizeContextSelection = originalAuthorizer }()

	_, err := UseContext("manager", "token")
	if err == nil {
		t.Fatal("expected unauthorized error")
	}

	after := mustReadFile(t, kubeconfigPath)
	if string(after) != string(original) {
		t.Fatal("kubeconfig changed even though authorization failed")
	}
}

func TestUseContextUpdatesOnlyCurrentContext(t *testing.T) {
	tempDir := t.TempDir()
	kubeconfigPath := filepath.Join(tempDir, "config")
	writeTestKubeconfig(t, kubeconfigPath)
	t.Setenv("KUBECONFIG", kubeconfigPath)

	originalCfg, err := clientcmd.LoadFromFile(kubeconfigPath)
	if err != nil {
		t.Fatalf("failed to load original kubeconfig: %v", err)
	}

	originalAuthorizer := authorizeContextSelection
	authorizeContextSelection = func(targetContext, token string) error { return nil }
	defer func() { authorizeContextSelection = originalAuthorizer }()

	result, err := UseContext("manager", "token")
	if err != nil {
		t.Fatalf("UseContext returned error: %v", err)
	}
	if result.CurrentContext != "kind-workload" {
		t.Fatalf("expected current kind-workload, got %s", result.CurrentContext)
	}
	if result.TargetContext != "kind-manager" {
		t.Fatalf("expected target kind-manager, got %s", result.TargetContext)
	}

	updatedCfg, err := clientcmd.LoadFromFile(kubeconfigPath)
	if err != nil {
		t.Fatalf("failed to load updated kubeconfig: %v", err)
	}

	if updatedCfg.CurrentContext != "kind-manager" {
		t.Fatalf("expected current-context kind-manager, got %s", updatedCfg.CurrentContext)
	}
	if len(updatedCfg.Contexts) != len(originalCfg.Contexts) {
		t.Fatalf("contexts length changed: %d -> %d", len(originalCfg.Contexts), len(updatedCfg.Contexts))
	}
	if len(updatedCfg.Clusters) != len(originalCfg.Clusters) {
		t.Fatalf("clusters length changed: %d -> %d", len(originalCfg.Clusters), len(updatedCfg.Clusters))
	}
	if len(updatedCfg.AuthInfos) != len(originalCfg.AuthInfos) {
		t.Fatalf("users length changed: %d -> %d", len(originalCfg.AuthInfos), len(updatedCfg.AuthInfos))
	}
}

func mustReadFile(t *testing.T, path string) []byte {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("failed to read %s: %v", path, err)
	}
	return b
}
