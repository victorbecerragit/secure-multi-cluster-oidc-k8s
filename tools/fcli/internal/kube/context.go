package kube

import "k8s.io/client-go/tools/clientcmd"

// CurrentContextName returns the current kubeconfig context name.
func CurrentContextName() (string, error) {
	configAccess := clientcmd.NewDefaultPathOptions()
	config, err := configAccess.GetStartingConfig()
	if err != nil {
		return "", err
	}
	return config.CurrentContext, nil
}
