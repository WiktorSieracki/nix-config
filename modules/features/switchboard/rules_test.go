package main

import (
	"reflect"
	"strings"
	"testing"
)

// A small catalog shaped like the real one: machine features without a
// home-manager part, account features with one, and one conflicting pair.
var rulesCat = Catalog{
	Meta: map[string]FeatureMeta{
		"niri":      {Kind: "config"},
		"desktop":   {Kind: "gui", Requires: []string{"niri"}},
		"sops":      {Kind: "config"},
		"tailscale": {Kind: "service"},
		"git":       {Kind: "cli", Requires: []string{"sops"}},
		"vscode":    {Kind: "gui", Requires: []string{"desktop"}},
		"t3code":    {Kind: "gui", Requires: []string{"desktop", "t3code-srv"}},
		"t3code-srv": {
			Kind: "service", Requires: []string{"tailscale"},
		},
		"needs-git": {Kind: "service", Requires: []string{"git"}},
		"pstack":    {Kind: "config", Conflicts: []string{"other-skills"}},
		"other-skills": {
			Kind: "config",
		},
	},
	HMNames: map[string]bool{
		"git": true, "vscode": true, "pstack": true, "other-skills": true,
	},
}

func spec(system []string, users map[string][]string) HostSpec {
	if users == nil {
		users = map[string][]string{}
	}
	return HostSpec{System: system, Users: users}
}

func TestValidateSpecClean(t *testing.T) {
	s := spec([]string{"niri", "desktop", "sops"},
		map[string][]string{"wiktor": {"git", "vscode"}})
	if got := ValidateSpec(rulesCat, s); len(got) != 0 {
		t.Errorf("valid spec reported problems: %v", got)
	}
}

func TestValidateSpecMirrorsTheLoader(t *testing.T) {
	cases := []struct {
		name string
		spec HostSpec
		want string
	}{
		{
			"system requires missing",
			spec([]string{"desktop"}, nil),
			"system feature 'desktop' requires 'niri' but `system` does not enable it",
		},
		{
			"user requires missing",
			spec(nil, map[string][]string{"wiktor": {"git"}}),
			"feature 'git' (user 'wiktor') requires 'sops' but neither `system` nor `users.wiktor` enables it",
		},
		{
			"home-manager part in system",
			spec([]string{"sops", "git"}, nil),
			"feature 'git' has a home-manager part but is enabled in `system` — move it to a user list, or its HM half attaches to nobody",
		},
		{
			"unknown system feature",
			spec([]string{"typo"}, nil),
			"system feature 'typo' is not a known feature (no NixOS/home-manager module and no featureMeta)",
		},
		{
			"unknown user feature",
			spec(nil, map[string][]string{"wiktor": {"typo"}}),
			"feature 'typo' (user 'wiktor') is not a known feature (no NixOS/home-manager module and no featureMeta)",
		},
		{
			// Declared on one side only (pstack), rendered name-sorted.
			"conflict within one account",
			spec(nil, map[string][]string{"wiktor": {"pstack", "other-skills"}}),
			"features 'other-skills' and 'pstack' conflict — user 'wiktor' may enable only one",
		},
	}
	for _, c := range cases {
		got := ValidateSpec(rulesCat, c.spec)
		if !contains(got, c.want) {
			t.Errorf("%s: problems = %q, want one to be %q", c.name, got, c.want)
		}
	}
}

// A user's requires may be met by `system` — that is not a problem.
func TestValidateSpecUserRequiresSatisfiedBySystem(t *testing.T) {
	s := spec([]string{"sops"}, map[string][]string{"wiktor": {"git"}})
	if got := ValidateSpec(rulesCat, s); len(got) != 0 {
		t.Errorf("problems = %v, want none", got)
	}
}

func TestToggleEnablePullsTheRequiresClosure(t *testing.T) {
	s := spec([]string{"sops"}, map[string][]string{"wiktor": {"git"}})
	res := Toggle(rulesCat, s, "wiktor", "vscode")
	if res.Refused || !res.Changed {
		t.Fatalf("enable refused: %q", res.Message)
	}
	want := []string{"git", "vscode", "desktop", "niri"}
	if got := res.Spec.Get("wiktor"); !reflect.DeepEqual(got, want) {
		t.Errorf("wiktor = %v, want %v (the feature, then its pulled deps sorted)", got, want)
	}
	if want := "Also enabled (required by vscode): desktop, niri"; res.Message != want {
		t.Errorf("message = %q, want %q", res.Message, want)
	}
	if !reflect.DeepEqual(s.Get("wiktor"), []string{"git"}) {
		t.Error("Toggle must not mutate the spec it was given")
	}
}

// Regression (feature notes, 2026-07-06): a dep already covered by `system`
// must not be pulled into the user's own list as a duplicate.
func TestToggleEnableDoesNotPullWhatSystemProvides(t *testing.T) {
	s := spec([]string{"niri", "desktop"}, map[string][]string{"wiktor": {}})
	res := Toggle(rulesCat, s, "wiktor", "vscode")
	if got := res.Spec.Get("wiktor"); !reflect.DeepEqual(got, []string{"vscode"}) {
		t.Errorf("wiktor = %v, want [vscode]", got)
	}
	if res.Message != "" {
		t.Errorf("message = %q, want none (nothing was pulled)", res.Message)
	}
}

func TestToggleRefusesAHomeManagerFeatureInSystem(t *testing.T) {
	s := spec([]string{"sops"}, map[string][]string{"wiktor": {}})
	res := Toggle(rulesCat, s, "system", "git")
	if !res.Refused || res.Changed {
		t.Fatal("enabling a home-manager feature in system must be refused")
	}
	if !strings.Contains(res.Message, "home-manager part") {
		t.Errorf("message = %q, want it to name the home-manager part", res.Message)
	}
	if !SpecEqual(res.Spec, s) {
		t.Error("a refusal must hand back the spec unchanged")
	}
}

// A system feature whose requires include an account feature can never be
// satisfied inside `system` — refuse instead of writing a file the loader rejects.
func TestToggleRefusesASystemFeatureThatNeedsAnAccountFeature(t *testing.T) {
	s := spec([]string{"sops"}, map[string][]string{"wiktor": {}})
	res := Toggle(rulesCat, s, "system", "needs-git")
	if !res.Refused {
		t.Fatalf("want a refusal, got %v", res.Spec)
	}
	if !strings.Contains(res.Message, "git") {
		t.Errorf("message = %q, want it to name the account feature", res.Message)
	}
}

func TestToggleRefusesAConflict(t *testing.T) {
	s := spec(nil, map[string][]string{"wiktor": {"other-skills"}})
	res := Toggle(rulesCat, s, "wiktor", "pstack")
	if !res.Refused {
		t.Fatalf("want a refusal, got %v", res.Spec)
	}
	if !strings.Contains(res.Message, "conflict") {
		t.Errorf("message = %q, want it to name the conflict", res.Message)
	}
}

func TestToggleDisable(t *testing.T) {
	s := spec([]string{"niri", "desktop"}, map[string][]string{"wiktor": {"vscode"}})
	res := Toggle(rulesCat, s, "wiktor", "vscode")
	if res.Refused || !res.Changed {
		t.Fatalf("disable refused: %q", res.Message)
	}
	if got := res.Spec.Get("wiktor"); len(got) != 0 {
		t.Errorf("wiktor = %v, want empty", got)
	}
}

func TestToggleDisableBlockedByADependentInTheSameSection(t *testing.T) {
	s := spec([]string{"niri", "desktop"}, nil)
	res := Toggle(rulesCat, s, "system", "niri")
	if !res.Refused {
		t.Fatal("niri is required by desktop — disabling it must be refused")
	}
	if want := "Cannot disable niri — required by: desktop"; res.Message != want {
		t.Errorf("message = %q, want %q", res.Message, want)
	}
}

// Dropping a system feature that only an account's feature needs would leave
// that account's requires unmet: the TUI used to allow it.
func TestToggleDisableInSystemBlockedByAnAccountsDependent(t *testing.T) {
	s := spec([]string{"tailscale"}, map[string][]string{"wiktor": {"t3code-srv"}})
	res := Toggle(rulesCat, s, "system", "tailscale")
	if !res.Refused {
		t.Fatal("tailscale is required by wiktor's t3code-srv — must be refused")
	}
	if want := "Cannot disable tailscale — required by: t3code-srv (wiktor)"; res.Message != want {
		t.Errorf("message = %q, want %q", res.Message, want)
	}
}

// …but when the account lists the dependency itself, system may let go of it.
func TestToggleDisableInSystemAllowedWhenTheAccountListsItToo(t *testing.T) {
	s := spec([]string{"tailscale"},
		map[string][]string{"wiktor": {"tailscale", "t3code-srv"}})
	if res := Toggle(rulesCat, s, "system", "tailscale"); res.Refused {
		t.Errorf("refused: %q", res.Message)
	}
}

// A feature listed in both `system` and the account: removing the account's
// copy leaves its dependents satisfied by system.
func TestToggleDisableInAccountAllowedWhenSystemProvidesIt(t *testing.T) {
	s := spec([]string{"tailscale"},
		map[string][]string{"wiktor": {"tailscale", "t3code-srv"}})
	res := Toggle(rulesCat, s, "wiktor", "tailscale")
	if res.Refused {
		t.Fatalf("refused: %q", res.Message)
	}
	if got := res.Spec.Get("wiktor"); !reflect.DeepEqual(got, []string{"t3code-srv"}) {
		t.Errorf("wiktor = %v, want [t3code-srv]", got)
	}
}

// Only on a file that is already broken: `system` holds a conflicting pair,
// which hides the same conflict in each account that lists one of the two.
// Taking the feature out of `system` would surface it there — a save would be
// refused, so the toggle is too.
func TestToggleDisableRefusedWhenItUncoversAConflict(t *testing.T) {
	cat := Catalog{Meta: map[string]FeatureMeta{
		"skills-a": {Kind: "config", Conflicts: []string{"skills-c"}},
		"skills-c": {Kind: "config"},
	}}
	s := spec([]string{"skills-a", "skills-c"}, map[string][]string{"u": {"skills-a"}})
	res := Toggle(cat, s, "system", "skills-a")
	if !res.Refused || !strings.Contains(res.Message, "conflict") {
		t.Errorf("want a refusal naming the conflict, got refused=%v %q", res.Refused, res.Message)
	}
	// The way out stays open: the account's copy can go first.
	if res := Toggle(cat, s, "u", "skills-a"); res.Refused {
		t.Errorf("removing the account's copy was refused: %q", res.Message)
	}
}

func TestToggleUnknownSection(t *testing.T) {
	res := Toggle(rulesCat, spec(nil, nil), "nobody", "git")
	if !res.Refused {
		t.Error("a section the host does not have must be refused")
	}
}

// A file that is already broken for an unrelated reason must stay editable:
// only problems the toggle itself introduces count.
func TestToggleIgnoresProblemsThatWereAlreadyThere(t *testing.T) {
	s := spec([]string{"stray", "niri"}, nil)
	if res := Toggle(rulesCat, s, "system", "desktop"); res.Refused {
		t.Errorf("refused: %q", res.Message)
	}
}

func TestSpecDiff(t *testing.T) {
	before := spec([]string{"niri", "sops"},
		map[string][]string{"wiktor": {"git"}, "work": {"git"}})
	after := spec([]string{"niri", "tailscale"},
		map[string][]string{"wiktor": {"git", "vscode"}, "work": {"git"}})
	got := SpecDiff(before, after)
	want := []SectionDiff{
		{Section: "system", Added: []string{"tailscale"}, Removed: []string{"sops"}},
		{Section: "wiktor", Added: []string{"vscode"}, Removed: []string{}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("SpecDiff = %+v, want %+v", got, want)
	}
	if got, want := SpecDiffString(got), "system: +tailscale -sops · wiktor: +vscode"; got != want {
		t.Errorf("SpecDiffString = %q, want %q", got, want)
	}
	if got := SpecDiff(before, before.Clone()); len(got) != 0 {
		t.Errorf("SpecDiff of equal specs = %+v, want none", got)
	}
}
