package main

// Repo I/O: host feature specs (features.json, ADR 0003/0004) and the
// featureMeta catalog from `nix eval`.

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// Real hosts only — image hosts (iso/vm) keep inline specs and are not
// Switchboard's target (ADR 0003).
var hostFiles = map[string]string{
	"desktopNixos": "modules/hosts/desktop-nixos/features.json",
	"laptopNixos":  "modules/hosts/laptop-nixos/features.json",
}

var hostOrder = []string{"desktopNixos", "laptopNixos"}

func featuresPath(repo, host string) string {
	return filepath.Join(repo, filepath.FromSlash(hostFiles[host]))
}

func readSpec(repo, host string) (HostSpec, error) {
	data, err := os.ReadFile(featuresPath(repo, host))
	if err != nil {
		return HostSpec{}, err
	}
	var spec HostSpec
	if err := json.Unmarshal(data, &spec); err != nil {
		return HostSpec{}, fmt.Errorf("parsing %s: %w", hostFiles[host], err)
	}
	if spec.Users == nil {
		spec.Users = map[string][]string{}
	}
	return spec, nil
}

func writeSpec(repo, host string, spec HostSpec) error {
	return os.WriteFile(featuresPath(repo, host), MarshalSpec(spec), 0o644)
}

func parseMeta(data []byte) (map[string]FeatureMeta, error) {
	var meta map[string]FeatureMeta
	if err := json.Unmarshal(data, &meta); err != nil {
		return nil, fmt.Errorf("parsing featureMeta: %w", err)
	}
	return meta, nil
}

func parseNames(data []byte) (map[string]bool, error) {
	var names []string
	if err := json.Unmarshal(data, &names); err != nil {
		return nil, fmt.Errorf("parsing module names: %w", err)
	}
	set := make(map[string]bool, len(names))
	for _, n := range names {
		set[n] = true
	}
	return set, nil
}
