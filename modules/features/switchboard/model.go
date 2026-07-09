package main

// Pure domain logic of Switchboard — no I/O, no TUI. Everything here mirrors
// the behaviour of the retired Python implementation 1:1 and is covered by
// unit tests in model_test.go.

import (
	"encoding/json"
	"sort"
	"strings"
)

// FeatureMeta mirrors one entry of `nix eval <repo>#featureMeta --json`.
// Extra fields (e.g. runtimeUntestable) are ignored on purpose.
type FeatureMeta struct {
	Requires []string `json:"requires"`
	Kind     string   `json:"kind"`
}

// HostSpec mirrors features.json (ADR 0003/0004): machine features in
// `system`, per-account user features in `users.<login>`.
type HostSpec struct {
	System []string            `json:"system"`
	Users  map[string][]string `json:"users"`
}

const sectionSystem = "system"

// Sections lists the editable sections: "system" first, then logins sorted.
func (s HostSpec) Sections() []string {
	logins := make([]string, 0, len(s.Users))
	for u := range s.Users {
		logins = append(logins, u)
	}
	sort.Strings(logins)
	return append([]string{sectionSystem}, logins...)
}

// Get returns the feature list of a section ("system" or a login).
func (s HostSpec) Get(section string) []string {
	if section == sectionSystem {
		return s.System
	}
	return s.Users[section]
}

// Set replaces the feature list of a section.
func (s *HostSpec) Set(section string, list []string) {
	if section == sectionSystem {
		s.System = list
		return
	}
	s.Users[section] = list
}

// Clone deep-copies the spec so edits never alias the original.
func (s HostSpec) Clone() HostSpec {
	c := HostSpec{
		System: append([]string(nil), s.System...),
		Users:  make(map[string][]string, len(s.Users)),
	}
	for u, l := range s.Users {
		c.Users[u] = append([]string(nil), l...)
	}
	return c
}

// SpecEqual compares two specs section-by-section, order-sensitively (the
// file order is meaningful — see ReconcileOrder).
func SpecEqual(a, b HostSpec) bool {
	if len(a.Users) != len(b.Users) || !equalLists(a.System, b.System) {
		return false
	}
	for u, l := range a.Users {
		bl, ok := b.Users[u]
		if !ok || !equalLists(l, bl) {
			return false
		}
	}
	return true
}

func equalLists(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// RequiresClosure returns the transitive closure of `requires` over meta,
// starting from names. Start names are excluded unless they require each
// other (a cycle).
func RequiresClosure(meta map[string]FeatureMeta, names []string) map[string]bool {
	seen := map[string]bool{}
	stack := append([]string(nil), names...)
	for len(stack) > 0 {
		n := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		for _, dep := range meta[n].Requires {
			if !seen[dep] {
				seen[dep] = true
				stack = append(stack, dep)
			}
		}
	}
	return seen
}

// Dependents lists the enabled features (other than name) that *directly*
// require name, sorted. Because features.json always holds a full closure,
// checking direct requires finds every dependent.
func Dependents(meta map[string]FeatureMeta, enabled []string, name string) []string {
	var out []string
	for _, g := range enabled {
		if g == name {
			continue
		}
		for _, d := range meta[g].Requires {
			if d == name {
				out = append(out, g)
				break
			}
		}
	}
	sort.Strings(out)
	return out
}

// FeatureDiff returns the names added and removed between two lists,
// preserving list order.
func FeatureDiff(oldList, newList []string) (added, removed []string) {
	oldSet := toSet(oldList)
	newSet := toSet(newList)
	for _, f := range newList {
		if !oldSet[f] {
			added = append(added, f)
		}
	}
	for _, f := range oldList {
		if !newSet[f] {
			removed = append(removed, f)
		}
	}
	return added, removed
}

// DiffString renders a feature diff as "+foo +bar -baz" (commit-message form).
func DiffString(added, removed []string) string {
	parts := make([]string, 0, len(added)+len(removed))
	for _, f := range added {
		parts = append(parts, "+"+f)
	}
	for _, f := range removed {
		parts = append(parts, "-"+f)
	}
	return strings.Join(parts, " ")
}

// ReconcileOrder builds the list to write: the file's existing order is kept
// for retained features, genuinely new names go last in the order they were
// enabled. A toggle off+on must not reorder the file.
func ReconcileOrder(original, enabled []string) []string {
	enabledSet := toSet(enabled)
	originalSet := toSet(original)
	out := make([]string, 0, len(enabled))
	for _, f := range original {
		if enabledSet[f] {
			out = append(out, f)
		}
	}
	for _, f := range enabled {
		if !originalSet[f] {
			out = append(out, f)
		}
	}
	return out
}

// MarshalSpec renders a features.json body in the repo's canonical shape:
// {"system": [...], "users": {...}}, pretty-printed with a 2-space indent,
// one name per line, trailing newline. Object keys sort deterministically
// (encoding/json sorts map keys).
func MarshalSpec(spec HostSpec) []byte {
	spec = spec.Clone()
	if spec.System == nil {
		spec.System = []string{}
	}
	for u, l := range spec.Users {
		if l == nil {
			spec.Users[u] = []string{}
		}
	}
	data, err := json.MarshalIndent(spec, "", "  ")
	if err != nil {
		// HostSpec cannot fail to marshal.
		panic(err)
	}
	return append(data, '\n')
}

// ShQuote renders args as a single POSIX-shell command line.
func ShQuote(args []string) string {
	parts := make([]string, len(args))
	for i, a := range args {
		if a != "" && !strings.ContainsAny(a, " \t\n'\"\\$&|;<>(){}[]*?~#!`") {
			parts[i] = a
		} else {
			parts[i] = "'" + strings.ReplaceAll(a, "'", `'\''`) + "'"
		}
	}
	return strings.Join(parts, " ")
}

func toSet(list []string) map[string]bool {
	s := make(map[string]bool, len(list))
	for _, f := range list {
		s[f] = true
	}
	return s
}
