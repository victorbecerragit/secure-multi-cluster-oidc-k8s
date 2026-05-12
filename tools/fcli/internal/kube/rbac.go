package kube

import (
	"context"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

// ValidateConnectivity checks if the client can reach the API and perform a basic operation.
func ValidateConnectivity(client kubernetes.Interface) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := client.CoreV1().Namespaces().List(ctx, metav1.ListOptions{})
	return err
}
