package main

// flake.lock parsing and diffing for the "Update flake" flow.

import (
	"encoding/json"
	"fmt"
	"reflect"
	"sort"
	"time"
)

type flakeLock struct {
	Nodes map[string]lockNode `json:"nodes"`
	Root  string              `json:"root"`
}

type lockNode struct {
	// Values are node-key strings, or arrays for `follows` references
	// (which we skip — they are not top-level inputs of their own).
	Inputs map[string]any `json:"inputs"`
	Locked map[string]any `json:"locked"`
}

// LockInputs maps each top-level flake input name to its `locked` attrs.
func LockInputs(data []byte) (map[string]map[string]any, error) {
	var lock flakeLock
	if err := json.Unmarshal(data, &lock); err != nil {
		return nil, fmt.Errorf("parsing flake.lock: %w", err)
	}
	out := map[string]map[string]any{}
	for name, key := range lock.Nodes[lock.Root].Inputs {
		if k, ok := key.(string); ok {
			out[name] = lock.Nodes[k].Locked
		}
	}
	return out, nil
}

// LockDiff returns human-readable "name: old → new" lines for every input
// whose locked attrs changed between two flake.lock contents.
func LockDiff(before, after []byte) ([]string, error) {
	b, err := LockInputs(before)
	if err != nil {
		return nil, err
	}
	a, err := LockInputs(after)
	if err != nil {
		return nil, err
	}
	names := map[string]bool{}
	for n := range b {
		names[n] = true
	}
	for n := range a {
		names[n] = true
	}
	sorted := make([]string, 0, len(names))
	for n := range names {
		sorted = append(sorted, n)
	}
	sort.Strings(sorted)

	var out []string
	for _, n := range sorted {
		if reflect.DeepEqual(b[n], a[n]) {
			continue
		}
		out = append(out, fmt.Sprintf("%s: %s → %s", n, fmtLocked(b[n]), fmtLocked(a[n])))
	}
	return out, nil
}

// fmtLocked renders locked attrs as "rev-prefix (YYYY-MM-DD)".
func fmtLocked(locked map[string]any) string {
	rev, _ := locked["rev"].(string)
	if rev == "" {
		rev, _ = locked["narHash"].(string)
	}
	if rev == "" {
		rev = "?"
	}
	if len(rev) > 12 {
		rev = rev[:12]
	}
	date := "?"
	if ts, ok := locked["lastModified"].(float64); ok {
		date = time.Unix(int64(ts), 0).UTC().Format("2006-01-02")
	}
	return fmt.Sprintf("%s (%s)", rev, date)
}
