package main

// The rules a host spec has to obey, shared by the TUI and the web UI: the
// loader's validation mirrored in Go, the toggle that never leaves a spec the
// loader would reject, and the per-section diff. Pure — no I/O. Tested in
// rules_test.go.

import (
	"fmt"
	"sort"
	"strings"
)

// ValidateSpec mirrors the validation of flake.lib.loadHost
// (modules/hosts/configurations.nix) and returns one line per problem, in the
// loader's wording and order. The one check it leaves out needs
// flake.meta.users — neither UI adds or removes accounts.
func ValidateSpec(cat Catalog, spec HostSpec) []string {
	logins := spec.Sections()[1:]
	// The loader also takes any NixOS module name here, which lets `nixos`
	// and `hosts/<host>` through; every real feature has featureMeta
	// (feature-coverage), so those two are not worth a third `nix eval`.
	known := func(m string) bool {
		_, ok := cat.Meta[m]
		return ok || cat.HMNames[m]
	}
	missing := func(enabled []string, m string) []string {
		var out []string
		for _, d := range cat.Meta[m].Requires {
			if !contains(spec.System, d) && !contains(enabled, d) {
				out = append(out, d)
			}
		}
		return out
	}

	var errs []string
	for _, m := range spec.System {
		if !known(m) {
			errs = append(errs, fmt.Sprintf(
				"system feature '%s' is not a known feature (no NixOS/home-manager module and no featureMeta)", m))
		}
	}
	for _, u := range logins {
		for _, m := range spec.Users[u] {
			if !known(m) {
				errs = append(errs, fmt.Sprintf(
					"feature '%s' (user '%s') is not a known feature (no NixOS/home-manager module and no featureMeta)", m, u))
			}
		}
	}
	for _, m := range spec.System {
		for _, d := range missing(nil, m) {
			errs = append(errs, fmt.Sprintf(
				"system feature '%s' requires '%s' but `system` does not enable it", m, d))
		}
	}
	for _, u := range logins {
		for _, m := range spec.Users[u] {
			for _, d := range missing(spec.Users[u], m) {
				errs = append(errs, fmt.Sprintf(
					"feature '%s' (user '%s') requires '%s' but neither `system` nor `users.%s` enables it", m, u, d, u))
			}
		}
	}
	systemClashes := clashes(cat.Meta, spec.System)
	for _, p := range systemClashes {
		errs = append(errs, fmt.Sprintf("features %s conflict — `system` may enable only one", p))
	}
	for _, u := range logins {
		for _, p := range clashes(cat.Meta, scopeOf(spec, u)) {
			if !contains(systemClashes, p) {
				errs = append(errs, fmt.Sprintf("features %s conflict — user '%s' may enable only one", p, u))
			}
		}
	}
	for _, m := range spec.System {
		if cat.HMNames[m] {
			errs = append(errs, fmt.Sprintf(
				"feature '%s' has a home-manager part but is enabled in `system` — move it to a user list, or its HM half attaches to nobody", m))
		}
	}
	return errs
}

// clashes lists the conflicting pairs within one scope as "'a' and 'b'",
// name-sorted so a conflict declared on both sides is reported once.
func clashes(meta map[string]FeatureMeta, enabled []string) []string {
	var out []string
	for _, m := range enabled {
		for _, c := range meta[m].Conflicts {
			if c == m || !contains(enabled, c) {
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

// scopeOf is the set a section's requires may be met from: `system` alone for
// the system section, `system` plus the account's own list for an account.
func scopeOf(spec HostSpec, section string) []string {
	if section == sectionSystem {
		return spec.System
	}
	return append(append([]string(nil), spec.System...), spec.Users[section]...)
}

// NewProblems returns the loader problems `after` has that `before` did not —
// what a change is answerable for. A file already broken for another reason
// stays editable.
func NewProblems(cat Catalog, before, after HostSpec) []string {
	had := toSet(ValidateSpec(cat, before))
	var out []string
	for _, p := range ValidateSpec(cat, after) {
		if !had[p] {
			out = append(out, p)
		}
	}
	return out
}

// ToggleResult is the outcome of flipping one feature in one section.
type ToggleResult struct {
	Spec    HostSpec // what to carry on with — the input itself after a refusal
	Changed bool
	Refused bool
	Message string // what else was enabled, or why nothing was ("" = nothing to say)
}

// Toggle flips name in section: enabling pulls in the transitive `requires`
// the section does not already see, and either direction is refused when the
// loader would reject the result. The spec passed in is never modified.
func Toggle(cat Catalog, spec HostSpec, section, name string) ToggleResult {
	refuse := func(format string, args ...any) ToggleResult {
		return ToggleResult{Spec: spec, Refused: true, Message: fmt.Sprintf(format, args...)}
	}
	if _, ok := spec.Users[section]; section != sectionSystem && !ok {
		return refuse("This host has no section '%s'", section)
	}

	if contains(spec.Get(section), name) {
		if blockers := Blockers(cat.Meta, spec, section, name); len(blockers) > 0 {
			return refuse("Cannot disable %s — required by: %s", name, strings.Join(blockers, ", "))
		}
		next := spec.Clone()
		kept := next.Get(section)[:0]
		for _, f := range next.Get(section) {
			if f != name {
				kept = append(kept, f)
			}
		}
		next.Set(section, kept)
		// Blockers covers `requires`. What is left is a file that was
		// already broken, where taking a feature out of `system` uncovers a
		// conflict the system-level one was hiding in an account.
		if problems := NewProblems(cat, spec, next); len(problems) > 0 {
			return refuse("Cannot disable %s — %s", name, strings.Join(problems, "; "))
		}
		// Deps that were auto-pulled for `name` stay enabled on purpose.
		return ToggleResult{Spec: next, Changed: true}
	}

	if section == sectionSystem && cat.HMNames[name] {
		return refuse("%s has a home-manager part — enable it for an account, not in system", name)
	}
	// A user section's requires may be satisfied by `system` too, so only
	// pull deps that aren't already covered by system + this section.
	scope := scopeOf(spec, section)
	var pulled []string
	for dep := range RequiresClosure(cat.Meta, []string{name}) {
		if dep != name && !contains(scope, dep) {
			pulled = append(pulled, dep)
		}
	}
	sort.Strings(pulled)
	if section == sectionSystem {
		for _, dep := range pulled {
			if cat.HMNames[dep] {
				return refuse("Cannot enable %s in system — it requires %s, which has a home-manager part; enable %s for an account instead",
					name, dep, name)
			}
		}
	}
	next := spec.Clone()
	// The file gets the full closure — the loader does no auto-pulling.
	next.Set(section, append(append(next.Get(section), name), pulled...))
	if problems := NewProblems(cat, spec, next); len(problems) > 0 {
		return refuse("Cannot enable %s — %s", name, strings.Join(problems, "; "))
	}
	res := ToggleResult{Spec: next, Changed: true}
	if len(pulled) > 0 {
		res.Message = fmt.Sprintf("Also enabled (required by %s): %s", name, strings.Join(pulled, ", "))
	}
	return res
}

// Blockers lists the enabled features that would lose a requirement if name
// left section. In `system` that includes each account's features ("git
// (wiktor)") unless the account lists name itself; in an account nothing
// blocks when `system` provides name anyway.
func Blockers(meta map[string]FeatureMeta, spec HostSpec, section, name string) []string {
	if section != sectionSystem {
		if contains(spec.System, name) {
			return nil
		}
		return Dependents(meta, spec.Users[section], name)
	}
	out := Dependents(meta, spec.System, name)
	for _, u := range spec.Sections()[1:] {
		if contains(spec.Users[u], name) {
			continue
		}
		for _, g := range Dependents(meta, spec.Users[u], name) {
			out = append(out, fmt.Sprintf("%s (%s)", g, u))
		}
	}
	return out
}

// SectionDiff is what changed in one section between two specs.
type SectionDiff struct {
	Section string   `json:"section"`
	Added   []string `json:"added"`
	Removed []string `json:"removed"`
}

// SpecDiff lists what changed between two specs, section by section (`system`
// first, then logins sorted); sections without a change are left out.
func SpecDiff(before, after HostSpec) []SectionDiff {
	sections := before.Sections()
	for _, s := range after.Sections() {
		if !contains(sections, s) {
			sections = append(sections, s)
		}
	}
	sort.Strings(sections[1:])

	var out []SectionDiff
	for _, s := range sections {
		added, removed := FeatureDiff(before.Get(s), after.Get(s))
		if len(added) == 0 && len(removed) == 0 {
			continue
		}
		// Never nil: the web UI reads these as JSON arrays.
		out = append(out, SectionDiff{
			Section: s,
			Added:   append([]string{}, added...),
			Removed: append([]string{}, removed...),
		})
	}
	return out
}

// SpecDiffString renders a spec diff as "system: +a -b · wiktor: +c"
// (commit-message form).
func SpecDiffString(diffs []SectionDiff) string {
	parts := make([]string, len(diffs))
	for i, d := range diffs {
		parts[i] = d.Section + ": " + DiffString(d.Added, d.Removed)
	}
	return strings.Join(parts, " · ")
}
