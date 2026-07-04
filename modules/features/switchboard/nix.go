package main

// Repo I/O: host feature lists (features.json, ADR 0003) and the featureMeta
// catalog from `nix eval`.

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// Real hosts only — image hosts (iso/vm) keep inline lists and are not
// Switchboard's target (ADR 0003).
var hostFiles = map[string]string{
	"desktopNixos": "modules/hosts/desktop-nixos/features.json",
	"laptopNixos":  "modules/hosts/laptop-nixos/features.json",
}

var hostOrder = []string{"desktopNixos", "laptopNixos"}

func featuresPath(repo, host string) string {
	return filepath.Join(repo, filepath.FromSlash(hostFiles[host]))
}

func readFeatures(repo, host string) ([]string, error) {
	data, err := os.ReadFile(featuresPath(repo, host))
	if err != nil {
		return nil, err
	}
	var features []string
	if err := json.Unmarshal(data, &features); err != nil {
		return nil, fmt.Errorf("parsing %s: %w", hostFiles[host], err)
	}
	return features, nil
}

func writeFeatures(repo, host string, features []string) error {
	return os.WriteFile(featuresPath(repo, host), MarshalFeatures(features), 0o644)
}

func parseMeta(data []byte) (map[string]FeatureMeta, error) {
	var meta map[string]FeatureMeta
	if err := json.Unmarshal(data, &meta); err != nil {
		return nil, fmt.Errorf("parsing featureMeta: %w", err)
	}
	return meta, nil
}
