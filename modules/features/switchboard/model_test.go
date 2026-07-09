package main

import (
	"reflect"
	"testing"
)

var testMeta = map[string]FeatureMeta{
	"git":     {Requires: []string{"sops"}, Kind: "cli"},
	"sops":    {Requires: []string{}, Kind: "config"},
	"niri":    {Requires: []string{"wiktor"}, Kind: "gui"},
	"wiktor":  {Requires: []string{}, Kind: "config"},
	"vscode":  {Requires: []string{"desktop"}, Kind: "gui"},
	"desktop": {Requires: []string{"niri"}, Kind: "gui"},
}

func TestRequiresClosureTransitive(t *testing.T) {
	got := RequiresClosure(testMeta, []string{"vscode"})
	want := map[string]bool{"desktop": true, "niri": true, "wiktor": true}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("closure(vscode) = %v, want %v", got, want)
	}
}

func TestRequiresClosureExcludesStart(t *testing.T) {
	if RequiresClosure(testMeta, []string{"git"})["git"] {
		t.Error("closure must not contain the start name (no cycle)")
	}
}

func TestRequiresClosureCycle(t *testing.T) {
	meta := map[string]FeatureMeta{
		"a": {Requires: []string{"b"}},
		"b": {Requires: []string{"a"}},
	}
	got := RequiresClosure(meta, []string{"a"})
	want := map[string]bool{"a": true, "b": true}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("closure(a) with cycle = %v, want %v", got, want)
	}
}

func TestDependents(t *testing.T) {
	enabled := []string{"wiktor", "niri", "desktop", "vscode", "sops"}
	if got := Dependents(testMeta, enabled, "niri"); !reflect.DeepEqual(got, []string{"desktop"}) {
		t.Errorf("Dependents(niri) = %v, want [desktop]", got)
	}
	if got := Dependents(testMeta, enabled, "sops"); got != nil {
		t.Errorf("Dependents(sops) = %v, want none (git not enabled)", got)
	}
	// A feature is never its own dependent.
	if got := Dependents(map[string]FeatureMeta{"a": {Requires: []string{"a"}}},
		[]string{"a"}, "a"); got != nil {
		t.Errorf("self-dependent = %v, want none", got)
	}
}

func TestFeatureDiff(t *testing.T) {
	added, removed := FeatureDiff([]string{"a", "b", "c"}, []string{"a", "c", "d", "e"})
	if !reflect.DeepEqual(added, []string{"d", "e"}) || !reflect.DeepEqual(removed, []string{"b"}) {
		t.Errorf("diff = +%v -%v, want +[d e] -[b]", added, removed)
	}
}

func TestDiffString(t *testing.T) {
	if got := DiffString([]string{"foo"}, []string{"bar", "baz"}); got != "+foo -bar -baz" {
		t.Errorf("DiffString = %q", got)
	}
}

// A toggle off+on must not reorder the file (regression: the Python version
// originally appended re-enabled features at the end).
func TestReconcileOrderToggleOffOn(t *testing.T) {
	original := []string{"a", "b", "c"}
	enabled := []string{"a", "c", "b"} // b was toggled off, then back on
	if got := ReconcileOrder(original, enabled); !reflect.DeepEqual(got, original) {
		t.Errorf("ReconcileOrder = %v, want %v", got, original)
	}
}

func TestReconcileOrderNewGoLast(t *testing.T) {
	original := []string{"a", "b", "c"}
	enabled := []string{"a", "b", "c", "x", "d"} // enabled in this order
	want := []string{"a", "b", "c", "x", "d"}
	if got := ReconcileOrder(original, enabled); !reflect.DeepEqual(got, want) {
		t.Errorf("ReconcileOrder = %v, want %v", got, want)
	}
}

func TestReconcileOrderRemoval(t *testing.T) {
	original := []string{"a", "b", "c"}
	enabled := []string{"a", "c"}
	want := []string{"a", "c"}
	if got := ReconcileOrder(original, enabled); !reflect.DeepEqual(got, want) {
		t.Errorf("ReconcileOrder = %v, want %v", got, want)
	}
}

func TestMarshalSpec(t *testing.T) {
	got := string(MarshalSpec(HostSpec{
		System: []string{"a", "b"},
		Users:  map[string][]string{"wiktor": {"fish"}},
	}))
	want := "{\n  \"system\": [\n    \"a\",\n    \"b\"\n  ],\n  \"users\": {\n    \"wiktor\": [\n      \"fish\"\n    ]\n  }\n}\n"
	if got != want {
		t.Errorf("MarshalSpec = %q, want %q", got, want)
	}
	if got := string(MarshalSpec(HostSpec{})); got != "{\n  \"system\": [],\n  \"users\": {}\n}\n" {
		t.Errorf("MarshalSpec(zero) = %q", got)
	}
}

func TestHostSpecSectionsAndAccessors(t *testing.T) {
	spec := HostSpec{
		System: []string{"niri"},
		Users:  map[string][]string{"work": {"slack"}, "wiktor": {"fish", "git"}},
	}
	if got := spec.Sections(); !reflect.DeepEqual(got, []string{"system", "wiktor", "work"}) {
		t.Errorf("Sections = %v, want [system wiktor work] (system first, then sorted logins)", got)
	}
	if got := spec.Get("wiktor"); !reflect.DeepEqual(got, []string{"fish", "git"}) {
		t.Errorf("Get(wiktor) = %v", got)
	}
	clone := spec.Clone()
	clone.Set("wiktor", []string{"fish"})
	if !reflect.DeepEqual(spec.Get("wiktor"), []string{"fish", "git"}) {
		t.Error("Clone must not alias the original — mutating the clone changed the original")
	}
	if !SpecEqual(spec, spec.Clone()) {
		t.Error("a spec must equal its own clone")
	}
	if SpecEqual(spec, clone) {
		t.Error("specs with different user lists must not be equal")
	}
}

func TestShQuote(t *testing.T) {
	cases := []struct {
		in   []string
		want string
	}{
		{[]string{"nh", "os", "test", "/home/w/repo"}, "nh os test /home/w/repo"},
		{[]string{"echo", "a b"}, "echo 'a b'"},
		{[]string{"echo", "it's"}, `echo 'it'\''s'`},
		{[]string{"echo", ""}, "echo ''"},
	}
	for _, c := range cases {
		if got := ShQuote(c.in); got != c.want {
			t.Errorf("ShQuote(%v) = %q, want %q", c.in, got, c.want)
		}
	}
}
