package kube

import (
	"testing"

	"k8s.io/client-go/kubernetes/fake"
)

func TestValidateConnectivity(t *testing.T) {
	// Use the fake clientset to test logic that expects a kubernetes.Interface
	client := fake.NewSimpleClientset()

	if err := ValidateConnectivity(client); err != nil {
		t.Errorf("ValidateConnectivity failed on fake client: %v", err)
	}
}
