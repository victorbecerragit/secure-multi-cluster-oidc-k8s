package kube

import (
	"errors"
	"fmt" // Added for logging
	"io/ioutil"
	"os" // Added for file operations
	"path/filepath"

	"gopkg.in/yaml.v3"

	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

// KubeConfig minimally represents the kubeconfig YAML for context switching tests.
type KubeConfig struct {
	CurrentContext string `yaml:"current-context"`
	Contexts       []struct {
		Name    string `yaml:"name"`
		Context struct {
			Cluster string `yaml:"cluster"`
			User    string `yaml:"user"`
		} `yaml:"context"`
	} `yaml:"contexts"`
	Clusters []struct {
		Name    string `yaml:"name"`
		Cluster struct {
			Server string `yaml:"server"`
		} `yaml:"cluster"`
	} `yaml:"clusters"`
	Users []struct {
		Name string                 `yaml:"name"`
		User map[string]interface{} `yaml:"user"`
	} `yaml:"users"`
}

// LoadKubeConfig loads the kubeconfig YAML from the default location and unmarshals it.
func LoadKubeConfig() (*KubeConfig, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	path := filepath.Join(home, ".kube", "config")
	data, err := ioutil.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg KubeConfig
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func ListClusters() ([]string, error) {
	loadingRules := clientcmd.NewDefaultClientConfigLoadingRules()
	config, err := loadingRules.Load()
	if err != nil {
		return nil, err
	}
	names := make([]string, 0, len(config.Clusters))
	for name := range config.Clusters {
		names = append(names, name)
	}
	return names, nil
}

func SwitchContext(cluster string) error {
	configAccess := clientcmd.NewDefaultPathOptions()
	kubeconfigPath := configAccess.GetDefaultFilename()

	// --- Backup Mechanism ---
	originalKubeconfig, err := os.ReadFile(kubeconfigPath)
	if err != nil {
		// If we can't read the original, we can't back it up, but we might still proceed.
		fmt.Fprintf(os.Stderr, "Warning: Could not read original kubeconfig for backup: %v\n", err)
	} else {
		backupPath := kubeconfigPath + ".bak"
		if err := os.WriteFile(backupPath, originalKubeconfig, 0600); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: Could not create kubeconfig backup at %s: %v\n", backupPath, err)
		} else {
			fmt.Fprintf(os.Stdout, "Kubeconfig backed up to %s\n", backupPath)
		}
	}
	// --- End Backup Mechanism ---

	config, err := configAccess.GetStartingConfig()
	if err != nil {
		return err
	}

	foundContext := ""
	for name, ctx := range config.Contexts {
		if ctx.Cluster == cluster {
			foundContext = name
			break
		}
	}

	if foundContext == "" {
		return errors.New("no context found for cluster: " + cluster)
	}

	config.CurrentContext = foundContext
	return clientcmd.ModifyConfig(configAccess, *config, true)
}

// GetKubeClient returns a Kubernetes clientset configured to use the provided OIDC token.
// It uses the default kubeconfig loading rules (e.g., KUBECONFIG env var or ~/.kube/config)
// to determine the target cluster based on the current context.
func GetKubeClient(token string) (kubernetes.Interface, error) {
	loadingRules := clientcmd.NewDefaultClientConfigLoadingRules()
	configOverrides := &clientcmd.ConfigOverrides{}
	kubeConfig := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(loadingRules, configOverrides)

	config, err := kubeConfig.ClientConfig()
	if err != nil {
		return nil, err
	}

	config.BearerToken = token

	return kubernetes.NewForConfig(config)
}
