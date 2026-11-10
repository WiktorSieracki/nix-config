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
	list := func(features ...string) string { return string(MarshalFeatures(features)) }
	repo := writeTree(t, map[string]string{
		"flake.nix": "{}\n",
		"modules/hosts/desktop-nixos/features.json": list("tailscale", "t3code-srv"),
		"modules/hosts/laptop-nixos/features.json":  list("sops", "git"),
		"modules/hosts/vps-nixos/features.json":     list("sops"),
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
	next, _ := m.Update(metaLoadedMsg{meta: rulesMeta})
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
	m := withCatalog(press(newTUI(t), "enter")) // desktopNixos

	m.toggle("tailscale")
	if want := "Cannot disable tailscale — required by: t3code-srv"; m.status != want || m.statusLevel != statusWarn {
		t.Errorf("status = %q (level %d), want the refusal %q", m.status, m.statusLevel, want)
	}
	if !reflect.DeepEqual(m.draft, []string{"tailscale", "t3code-srv"}) {
		t.Errorf("draft = %v, want it untouched by the refused toggle", m.draft)
	}

	m.toggle("vscode")
	if want := []string{"tailscale", "t3code-srv", "vscode", "desktop", "niri"}; !reflect.DeepEqual(m.draft, want) {
		t.Errorf("draft = %v, want %v", m.draft, want)
	}
	if want := "Also enabled (required by vscode): desktop, niri"; m.status != want || m.statusLevel != statusInfo {
		t.Errorf("status = %q (level %d), want %q", m.status, m.statusLevel, want)
	}
	// One list: the host screen has no sections to tab through.
	if view := m.View(); strings.Contains(view, "system") {
		t.Errorf("the host screen still talks about a system section:\n%s", view)
	}

	// Review and confirm: the file gets the list, in the canonical shape.
	m = press(m, "enter", "enter")
	saved, err := readFeatures(m.hosts.path(m.repo, "desktopNixos"))
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"tailscale", "t3code-srv", "vscode", "desktop", "niri"}; !reflect.DeepEqual(saved, want) {
		t.Errorf("saved = %v, want %v", saved, want)
	}
	if want := "switchboard: desktopNixos +vscode +desktop +niri"; m.fin.commitMsg != want {
		t.Errorf("commit message = %q, want %q", m.fin.commitMsg, want)
	}
}
