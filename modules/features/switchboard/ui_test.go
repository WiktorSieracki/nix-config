package main

import (
	"reflect"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

// newTUI opens the TUI model over a throwaway repo with three hosts — no
// terminal involved: keys go straight into Update.
func newTUI(t *testing.T) model {
	t.Helper()
	list := func(system []string, users map[string][]string) string {
		return string(MarshalSpec(spec(system, users)))
	}
	repo := writeTree(t, map[string]string{
		"flake.nix": "{}\n",
		"modules/hosts/desktop-nixos/features.json": list([]string{"tailscale"}, map[string][]string{"wiktor": {"t3code-srv"}}),
		"modules/hosts/laptop-nixos/features.json":  list([]string{"sops"}, map[string][]string{"wiktor": {"git"}}),
		"modules/hosts/vps-nixos/features.json":     list([]string{"sops"}, map[string][]string{"wiktor": {}}),
	})
	hosts, err := discoverHosts(repo)
	if err != nil {
		t.Fatal(err)
	}
	return newModel(repo, hosts)
}

// press feeds keys ("enter", or a rune such as "j") through Update.
func press(m model, keys ...string) model {
	for _, k := range keys {
		msg := tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(k)}
		if k == "enter" {
			msg = tea.KeyMsg{Type: tea.KeyEnter}
		}
		next, _ := m.Update(msg)
		m = next.(model)
	}
	return m
}

// withCatalog stands in for the `nix eval` the host screen kicks off.
func withCatalog(m model) model {
	next, _ := m.Update(metaLoadedMsg{meta: rulesCat.Meta, hmNames: rulesCat.HMNames})
	return next.(model)
}

// The home list follows the hosts the repo has — vpsNixos was missing while
// the list was hardcoded.
func TestTUIHomeListsEveryHost(t *testing.T) {
	m := newTUI(t)
	view := m.View()
	for _, host := range []string{"desktopNixos", "laptopNixos", "vpsNixos"} {
		if !strings.Contains(view, host) {
			t.Errorf("home screen does not list %s:\n%s", host, view)
		}
	}
	// G lands on the last item, Clean — two past the hosts.
	if got := press(m, "G").homeCursor; got != 4 {
		t.Errorf("G moved the cursor to %d, want 4 (Clean)", got)
	}
	m = press(m, "j", "j", "enter")
	if m.scr != scrHost || m.host != "vpsNixos" {
		t.Errorf("the third item opened screen %d host %q, want the vpsNixos host screen", m.scr, m.host)
	}
}

// The TUI toggles through rules.go: what the web UI refuses, it refuses.
func TestTUIToggleFollowsTheSharedRules(t *testing.T) {
	m := withCatalog(press(newTUI(t), "enter")) // desktopNixos, section `system`

	m.toggle("tailscale")
	if want := "Cannot disable tailscale — required by: t3code-srv (wiktor)"; m.status != want || m.statusLevel != statusWarn {
		t.Errorf("status = %q (level %d), want the refusal %q", m.status, m.statusLevel, want)
	}
	if !reflect.DeepEqual(m.spec.System, []string{"tailscale"}) {
		t.Errorf("system = %v, want it untouched by the refused toggle", m.spec.System)
	}

	m.toggle("git")
	if m.isEnabled("git") || !strings.Contains(m.status, "home-manager part") {
		t.Errorf("a home-manager feature went into system (status %q)", m.status)
	}

	m.switchSection(1) // wiktor
	m.toggle("vscode")
	if want := []string{"t3code-srv", "vscode", "desktop", "niri"}; !reflect.DeepEqual(m.enabled(), want) {
		t.Errorf("wiktor = %v, want %v", m.enabled(), want)
	}
	if want := "Also enabled (required by vscode): desktop, niri"; m.status != want || m.statusLevel != statusInfo {
		t.Errorf("status = %q (level %d), want %q", m.status, m.statusLevel, want)
	}

	// Review and confirm: the file gets the reconciled lists.
	m = press(m, "enter", "enter")
	saved, err := readSpec(m.hosts.path(m.repo, "desktopNixos"))
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"t3code-srv", "vscode", "desktop", "niri"}; !reflect.DeepEqual(saved.Users["wiktor"], want) {
		t.Errorf("saved wiktor = %v, want %v", saved.Users["wiktor"], want)
	}
	if want := "switchboard: desktopNixos wiktor: +vscode +desktop +niri"; m.fin.commitMsg != want {
		t.Errorf("commit message = %q, want %q", m.fin.commitMsg, want)
	}
}
