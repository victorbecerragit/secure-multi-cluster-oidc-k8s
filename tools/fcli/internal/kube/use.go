package kube

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

type UseResult struct {
	CurrentContext string
	TargetContext  string
	LogicalCluster string
}

var authorizeContextSelection = authorizeContextWithToken

// UseContext resolves a logical cluster name to a kubeconfig context, validates
// access with the provided token, and updates only current-context.
func UseContext(logicalCluster, token string) (*UseResult, error) {
	configAccess := clientcmd.NewDefaultPathOptions()
	config, err := configAccess.GetStartingConfig()
	if err != nil {
		return nil, err
	}

	current := config.CurrentContext
	target, err := resolveContextName(config, logicalCluster)
	if err != nil {
		return nil, err
	}

	if err := authorizeContextSelection(target, token); err != nil {
		if apierrors.IsForbidden(err) || apierrors.IsUnauthorized(err) {
			return nil, fmt.Errorf("unauthorized cluster selection %q: %w", logicalCluster, err)
		}
		return nil, fmt.Errorf("authorization check failed for %q: %w", logicalCluster, err)
	}

	config.CurrentContext = target
	if err := clientcmd.ModifyConfig(configAccess, *config, true); err != nil {
		return nil, err
	}

	return &UseResult{
		CurrentContext: current,
		TargetContext:  target,
		LogicalCluster: logicalCluster,
	}, nil
}

func resolveContextName(config *clientcmdapi.Config, selection string) (string, error) {
	requested := strings.TrimSpace(selection)
	if requested == "" {
		return "", errors.New("cluster selection cannot be empty")
	}

	if _, ok := config.Contexts[requested]; ok {
		return requested, nil
	}

	lower := strings.ToLower(requested)
	canonicalCluster := requested
	switch lower {
	case "manager":
		canonicalCluster = "kind-manager"
	case "workload":
		canonicalCluster = "kind-workload"
	}

	matches := contextsForCluster(config, canonicalCluster)
	if len(matches) == 1 {
		return matches[0], nil
	}
	if len(matches) > 1 {
		if config.CurrentContext != "" {
			for _, match := range matches {
				if match == config.CurrentContext {
					return match, nil
				}
			}
		}
		return "", fmt.Errorf("cluster %q maps to multiple contexts: %s; use an explicit context name", selection, strings.Join(matches, ", "))
	}

	available := availableContextKeys(config)
	return "", fmt.Errorf("unknown cluster %q. Available contexts: %s", selection, strings.Join(available, ", "))
}

func contextsForCluster(config *clientcmdapi.Config, clusterName string) []string {
	var matches []string
	for name, ctx := range config.Contexts {
		if ctx.Cluster == clusterName {
			matches = append(matches, name)
		}
	}
	sort.Strings(matches)
	return matches
}

func availableContextKeys(config *clientcmdapi.Config) []string {
	keys := make([]string, 0, len(config.Contexts))
	for k := range config.Contexts {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func authorizeContextWithToken(targetContext, token string) error {
	if token == "" {
		return errors.New("missing token")
	}

	loadingRules := clientcmd.NewDefaultClientConfigLoadingRules()
	overrides := &clientcmd.ConfigOverrides{CurrentContext: targetContext}
	deferred := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(loadingRules, overrides)

	restConfig, err := deferred.ClientConfig()
	if err != nil {
		return err
	}
	restConfig.BearerToken = token

	client, err := kubernetes.NewForConfig(restConfig)
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err = client.CoreV1().Namespaces().List(ctx, metav1.ListOptions{Limit: 1})
	return err
}
