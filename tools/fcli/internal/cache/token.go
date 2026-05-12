package cache

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
)

type Token struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	IDToken      string `json:"id_token"`
	Expiry       int64  `json:"expiry"`
}

// tokenCacheBaseDir allows overriding the base directory for token caching, primarily for testing.
var tokenCacheBaseDir string

// SetTokenCacheBaseDir sets a custom base directory for token caching.
// This should only be used for testing purposes.
func SetTokenCacheBaseDir(dir string) {
	tokenCacheBaseDir = dir
}

func tokenCachePath() (string, error) {
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
	return filepath.Join(cacheDir, "token.json"), nil
}

func SaveToken(token *Token) error {
	path, err := tokenCachePath()
	if err != nil {
		return err
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0600)
	if err != nil {
		return err
	}
	defer f.Close()
	return json.NewEncoder(f).Encode(token)
}

func LoadToken() (*Token, error) {
	path, err := tokenCachePath()
	if err != nil {
		return nil, err
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	t := &Token{}
	if err := json.NewDecoder(f).Decode(t); err != nil {
		return nil, err
	}
	if t.AccessToken == "" {
		return nil, errors.New("no access token found")
	}
	return t, nil
}
