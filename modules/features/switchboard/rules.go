package main

// The rules a host's feature list has to obey, shared by the TUI and the web
// UI: the loader's validation mirrored in Go, and the toggle that never leaves
// a list the loader would reject. Pure — no I/O. Tested in rules_test.go.

import (
	"fmt"
	"sort"
	"strings"
)

// ValidateFeatures mirrors the validation of flake.lib.loadHost
// (modules/hosts/configurations.nix) and returns one line per problem, in the
// loader's wording and order. The checks it leaves out are about the host's
// accounts, which are not in features.json.
func ValidateFeatures(meta map[string]FeatureMeta, features []string) []string {
	var errs []string
	for _, m := range features {
		// The loader also takes any NixOS or home-manager module name here,
		// which lets `nixos` and `hosts/<host>` through; every real feature
		// has featureMeta (feature-coverage), so the catalog is the test.
		if _, known := meta[m]; !known {
			errs = append(errs, fmt.Sprintf(
				"feature '%s' is not a known feature (no NixOS/home-manager module and no featureMeta)", m))
		}
	}
	for _, m := range features {
		for _, d := range meta[m].Requires {
			if !contains(features, d) {
				errs = append(errs, fmt.Sprintf(
					"feature '%s' requires '%s' but the host does not enable it", m, d))
			}
		}
	}
	for _, p := range clashes(meta, features) {
		errs = append(errs, fmt.Sprintf("features %s conflict — a host may enable only one", p))
	}
	return errs
}

// clashes lists the conflicting pairs as "'a' and 'b'", name-sorted so a
// conflict declared on both sides is reported once.
func clashes(meta map[string]FeatureMeta, features []string) []string {
	var out []string
	for _, m := range features {
		for _, c := range meta[m].Conflicts {
			if c == m || !contains(features, c) {
				continue
			}
			a, b := m, c
			if b < a {
				a, b = b, a
			}
			if p := fmt.Sprintf("'%s' and '%s'", a, b); !contains(out, p) {
				out = append(out, p)
			}
		}
	}
	return out
}

// NewProblems returns the loader problems `after` has that `before` did not —
// what a change is answerable for. A file already broken for another reason
// stays editable.
func NewProblems(meta map[string]FeatureMeta, before, after []string) []string {
	had := toSet(ValidateFeatures(meta, before))
	var out []string
	for _, p := range ValidateFeatures(meta, after) {
		if !had[p] {
			out = append(out, p)
		}
	}
	return out
}

// ToggleResult is the outcome of flipping one feature on one host.
type ToggleResult struct {
	Features []string // what to carry on with — the input itself after a refusal
	Changed  bool
	Refused  bool
	Message  string // what else was enabled, or why nothing was ("" = nothing to say)
}

// Toggle flips name: enabling pulls in the transitive `requires` the list
// does not have yet, and either direction is refused when the loader would
// reject the result. The list passed in is never modified.
func Toggle(meta map[string]FeatureMeta, features []string, name string) ToggleResult {
	refuse := func(format string, args ...any) ToggleResult {
		return ToggleResult{Features: features, Refused: true, Message: fmt.Sprintf(format, args...)}
	}

	if contains(features, name) {
		// The file always holds a full closure, so the direct dependents are
		// every dependent.
		if dependents := Dependents(meta, features, name); len(dependents) > 0 {
			return refuse("Cannot disable %s — required by: %s", name, strings.Join(dependents, ", "))
		}
		next := make([]string, 0, len(features))
		for _, f := range features {
			if f != name {
				next = append(next, f)
			}
		}
		// Deps that were auto-pulled for `name` stay enabled on purpose.
		return ToggleResult{Features: next, Changed: true}
	}

	var pulled []string
	for dep := range RequiresClosure(meta, []string{name}) {
		if dep != name && !contains(features, dep) {
			pulled = append(pulled, dep)
		}
	}
	sort.Strings(pulled)
	// The file gets the full closure — the loader does no auto-pulling.
	next := append(append(append([]string(nil), features...), name), pulled...)
	if problems := NewProblems(meta, features, next); len(problems) > 0 {
		return refuse("Cannot enable %s — %s", name, strings.Join(problems, "; "))
	}
	res := ToggleResult{Features: next, Changed: true}
	if len(pulled) > 0 {
		res.Message = fmt.Sprintf("Also enabled (required by %s): %s", name, strings.Join(pulled, ", "))
	}
	return res
}
