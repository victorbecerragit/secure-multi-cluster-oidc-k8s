package kube

import (
	"context"
	"os"
	"testing"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes/fake"
)

func TestGetKubeClient(t *testing.T) {
	// Create a dummy kubeconfig file for the test
	tmpfile, err := os.CreateTemp("", "kubeconfig")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(tmpfile.Name())

	content := `
apiVersion: v1
clusters:
- cluster:
    server: https://localhost:8443
  name: test-cluster
contexts:
- context:
    cluster: test-cluster
    user: test-user
  name: test-context
current-context: test-context
kind: Config
users:
- name: test-user
  user:
    token: initial-token
`
	if _, err := tmpfile.Write([]byte(content)); err != nil {
		t.Fatal(err)
	}
	tmpfile.Close()

	// Override KUBECONFIG env var so GetKubeClient finds our mock config
	os.Setenv("KUBECONFIG", tmpfile.Name())
	defer os.Unsetenv("KUBECONFIG")

	client, err := GetKubeClient("test-token")
	if err != nil {
		t.Fatalf("Failed to create kube client: %v", err)
	}
	if client == nil {
		t.Fatal("Kube client is nil")
	}
}

func TestFakeClientUsage(t *testing.T) {
	// This demonstrates how to use the fake clientset to test logic
	// that expects a kubernetes.Interface without needing a real cluster.
	client := fake.NewSimpleClientset()

	// Verification: listing namespaces on a fake client should not error
	_, err := client.CoreV1().Namespaces().List(context.Background(), metav1.ListOptions{})
	if err != nil {
		t.Fatalf("Fake client failed: %v", err)
	}
}
