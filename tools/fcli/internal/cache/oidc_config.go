package cache

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
)

type OIDCConfig struct {
	IssuerURL string `json:"issuer_url"`
	ClientID  string `json:"client_id"`
}

func oidcConfigPath() (string, error) {
	baseDir := tokenCacheBaseDir
	if baseDir == "" {
		var err error
		baseDir, err = os.UserHomeDir()
		if err != nil {
			return "", err
		}
	}
	cacheDir := filepath.Join(baseDir, ".fcli")
	if err := os.MkdirAll(cacheDir, 0700); err != nil {
		return "", err
	}
	return filepath.Join(cacheDir, "oidc-config.json"), nil
}

func SaveOIDCConfig(cfg *OIDCConfig) error {
	if cfg == nil {
		return errors.New("nil oidc config")
	}
	if cfg.IssuerURL == "" || cfg.ClientID == "" {
		return errors.New("oidc config requires issuer_url and client_id")
	}

	path, err := oidcConfigPath()
	if err != nil {
		return err
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0600)
	if err != nil {
		return err
	}
	defer f.Close()
	return json.NewEncoder(f).Encode(cfg)
}

func LoadOIDCConfig() (*OIDCConfig, error) {
	path, err := oidcConfigPath()
	if err != nil {
		return nil, err
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	cfg := &OIDCConfig{}
	if err := json.NewDecoder(f).Decode(cfg); err != nil {
		return nil, err
	}
	if cfg.IssuerURL == "" || cfg.ClientID == "" {
		return nil, errors.New("invalid oidc config")
	}
	return cfg, nil
}
