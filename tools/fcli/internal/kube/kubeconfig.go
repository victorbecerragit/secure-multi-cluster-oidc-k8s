package kube

import (
	"io/ioutil"
	"os"
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
	config, err := configAccess.GetStartingConfig()
	if err != nil {
		return err
	}

	targetContext, err := resolveContextName(config, cluster)
	if err != nil {
		return err
	}

	config.CurrentContext = targetContext
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
