package integration

import (
	"testing"
	"tools/fcli/internal/kube"
)

func TestClusters(t *testing.T) {
	clusters, err := kube.ListClusters()
	if err != nil {
		t.Fatalf("ListClusters failed: %v", err)
	}
	t.Logf("clusters: %v", clusters)
	// Optionally: assert at least one cluster if test env is set up
}
