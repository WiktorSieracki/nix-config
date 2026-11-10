package main

import (
	"reflect"
	"strings"
	"testing"
)

// A small catalog shaped like the real one: a requires chain of depth three,
// a service two things build on, and one conflicting pair.
var rulesMeta = map[string]FeatureMeta{
	"niri":         {Kind: "config"},
	"desktop":      {Kind: "gui", Requires: []string{"niri"}},
	"sops":         {Kind: "config"},
	"tailscale":    {Kind: "service"},
	"git":          {Kind: "cli", Requires: []string{"sops"}},
	"vscode":       {Kind: "gui", Requires: []string{"desktop"}},
	"t3code-srv":   {Kind: "service", Requires: []string{"tailscale"}},
	"t3code":       {Kind: "gui", Requires: []string{"desktop", "t3code-srv"}},
	"pstack":       {Kind: "config", Conflicts: []string{"other-skills"}},
	"other-skills": {Kind: "config"},
}

func TestValidateFeaturesClean(t *testing.T) {
	list := []string{"niri", "desktop", "sops", "git", "vscode"}
	if got := ValidateFeatures(rulesMeta, list); len(got) != 0 {
		t.Errorf("a valid list reported problems: %v", got)
	}
}

func TestValidateFeaturesMirrorsTheLoader(t *testing.T) {
	cases := []struct {
		name string
		list []string
		want string
	}{
		{
			"requires missing",
			[]string{"desktop"},
			"feature 'desktop' requires 'niri' but the host does not enable it",
		},
		{
			"not a feature",
			[]string{"typo"},
			"feature 'typo' is not a known feature (no NixOS/home-manager module and no featureMeta)",
		},
		{
			// Declared on one side only (pstack), rendered name-sorted.
			"conflict",
			[]string{"pstack", "other-skills"},
			"features 'other-skills' and 'pstack' conflict — a host may enable only one",
		},
	}
	for _, c := range cases {
		got := ValidateFeatures(rulesMeta, c.list)
		if !contains(got, c.want) {
			t.Errorf("%s: problems = %q, want one to be %q", c.name, got, c.want)
		}
	}
}

func TestToggleEnablePullsTheRequiresClosure(t *testing.T) {
	list := []string{"sops", "git"}
	res := Toggle(rulesMeta, list, "vscode")
	if res.Refused || !res.Changed {
		t.Fatalf("enable refused: %q", res.Message)
	}
	want := []string{"sops", "git", "vscode", "desktop", "niri"}
	if !reflect.DeepEqual(res.Features, want) {
		t.Errorf("features = %v, want %v (the feature, then its pulled deps sorted)", res.Features, want)
	}
	if want := "Also enabled (required by vscode): desktop, niri"; res.Message != want {
		t.Errorf("message = %q, want %q", res.Message, want)
	}
	if !reflect.DeepEqual(list, []string{"sops", "git"}) {
		t.Error("Toggle must not modify the list it was given")
	}
}

// What the host already enables is not pulled a second time.
func TestToggleEnableDoesNotPullWhatIsThere(t *testing.T) {
	res := Toggle(rulesMeta, []string{"niri", "desktop"}, "vscode")
	if want := []string{"niri", "desktop", "vscode"}; !reflect.DeepEqual(res.Features, want) {
		t.Errorf("features = %v, want %v", res.Features, want)
	}
	if res.Message != "" {
		t.Errorf("message = %q, want none (nothing was pulled)", res.Message)
	}
}

func TestToggleRefusesAConflict(t *testing.T) {
	list := []string{"other-skills"}
	res := Toggle(rulesMeta, list, "pstack")
	if !res.Refused || res.Changed {
		t.Fatalf("want a refusal, got %v", res.Features)
	}
	if !strings.Contains(res.Message, "conflict") {
		t.Errorf("message = %q, want it to name the conflict", res.Message)
	}
	if !reflect.DeepEqual(res.Features, list) {
		t.Error("a refusal must hand back the list unchanged")
	}
}

func TestToggleRefusesANameThatIsNotAFeature(t *testing.T) {
	if res := Toggle(rulesMeta, []string{"sops"}, "typo"); !res.Refused {
		t.Errorf("enabled a name the catalog does not have: %v", res.Features)
	}
}

func TestToggleDisable(t *testing.T) {
	res := Toggle(rulesMeta, []string{"niri", "desktop", "vscode"}, "vscode")
	if res.Refused || !res.Changed {
		t.Fatalf("disable refused: %q", res.Message)
	}
	// Its pulled deps stay: they may be wanted for their own sake.
	if want := []string{"niri", "desktop"}; !reflect.DeepEqual(res.Features, want) {
		t.Errorf("features = %v, want %v", res.Features, want)
	}
}

func TestToggleDisableBlockedByADependent(t *testing.T) {
	res := Toggle(rulesMeta, []string{"tailscale", "niri", "desktop", "t3code-srv", "t3code"}, "tailscale")
	if !res.Refused {
		t.Fatal("tailscale is required by t3code-srv — disabling it must be refused")
	}
	if want := "Cannot disable tailscale — required by: t3code-srv"; res.Message != want {
		t.Errorf("message = %q, want %q", res.Message, want)
	}
	// desktop has two dependents; both are named.
	res = Toggle(rulesMeta, []string{"niri", "desktop", "vscode", "tailscale", "t3code-srv", "t3code"}, "desktop")
	if want := "Cannot disable desktop — required by: t3code, vscode"; res.Message != want {
		t.Errorf("message = %q, want %q", res.Message, want)
	}
}

// A file that is already broken for an unrelated reason must stay editable:
// only problems the toggle itself introduces count.
func TestToggleIgnoresProblemsThatWereAlreadyThere(t *testing.T) {
	if res := Toggle(rulesMeta, []string{"stray", "niri"}, "desktop"); res.Refused {
		t.Errorf("refused: %q", res.Message)
	}
	// …and the stray itself can be switched off.
	if res := Toggle(rulesMeta, []string{"stray", "niri"}, "stray"); res.Refused {
		t.Errorf("removing the stray was refused: %q", res.Message)
	}
}
