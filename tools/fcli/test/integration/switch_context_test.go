package integration

import (
	"os"
	"testing"
	"tools/fcli/internal/kube"

	"gopkg.in/yaml.v3"
)

// switchContextByContextName switches context by context name (helper for test)
func switchContextByContextName(contextName string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	path := home + "/.kube/config"
	f, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var cfg kube.KubeConfig
	if err := yaml.Unmarshal(f, &cfg); err != nil {
		return err
	}
	cfg.CurrentContext = contextName
	out, err := yaml.Marshal(&cfg)
	if err != nil {
		return err
	}
	return os.WriteFile(path, out, 0600)
}
func TestSwitchContext(t *testing.T) {
	// Setup: load kubeconfig and get clusters
	clusters, err := kube.ListClusters()
	if err != nil {
		t.Fatalf("ListClusters failed: %v", err)
	}
	if len(clusters) < 2 {
		t.Skip("Need at least two clusters in kubeconfig to test context switching")
	}

	// Load current context
	cfg, err := kube.LoadKubeConfig()
	if err != nil {
		t.Fatalf("LoadKubeConfig failed: %v", err)
	}
	origContext := cfg.CurrentContext
	currentCluster := ""
	for _, ctx := range cfg.Contexts {
		if ctx.Name == origContext {
			currentCluster = ctx.Context.Cluster
			break
		}
	}
	if currentCluster == "" {
		t.Fatalf("unable to determine cluster for current context %q", origContext)
	}

	targetCluster := ""
	for _, c := range clusters {
		if c != currentCluster {
			targetCluster = c
			break
		}
	}
	if targetCluster == "" {
		t.Skip("No alternate cluster available for context switching test")
	}

	if err := kube.SwitchContext(targetCluster); err != nil {
		t.Fatalf("SwitchContext failed: %v", err)
	}
	cfg2, err := kube.LoadKubeConfig()
	if err != nil {
		t.Fatalf("Reload after switch failed: %v", err)
	}
	if cfg2.CurrentContext == origContext {
		t.Errorf("Context did not change after switch (still %s)", origContext)
	}

	// Restore original context by name
	_ = switchContextByContextName(origContext)
}
