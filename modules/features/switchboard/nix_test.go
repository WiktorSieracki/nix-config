package main

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

// writeTree creates files (repo-relative slash paths → content) under a new
// temp dir and returns it.
func writeTree(t *testing.T, files map[string]string) string {
	t.Helper()
	root := t.TempDir()
	for name, content := range files {
		path := filepath.Join(root, filepath.FromSlash(name))
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return root
}

func TestHostName(t *testing.T) {
	cases := map[string]string{
		"desktop-nixos": "desktopNixos",
		"vps-nixos":     "vpsNixos",
		"laptop":        "laptop",
		"a-b-c":         "aBC",
	}
	for dir, want := range cases {
		if got := hostName(dir); got != want {
			t.Errorf("hostName(%q) = %q, want %q", dir, got, want)
		}
	}
}

func TestDiscoverHosts(t *testing.T) {
	repo := writeTree(t, map[string]string{
		"modules/hosts/desktop-nixos/features.json": `[]`,
		"modules/hosts/vps-nixos/features.json":     `[]`,
		// The name a host registers under wins over its folder name.
		"modules/hosts/odd-folder/features.json": `[]`,
		"modules/hosts/odd-folder/default.nix":   "{\n  flake.hostSpecs.realName = spec;\n}\n",
		// Image hosts keep inline specs: no features.json, not a target.
		"modules/hosts/iso/default.nix": "{}",
	})
	hosts, err := discoverHosts(repo)
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"desktopNixos", "realName", "vpsNixos"}; !reflect.DeepEqual(hosts.order, want) {
		t.Errorf("hosts = %v, want %v (sorted)", hosts.order, want)
	}
	if got, want := hosts.files["realName"], "modules/hosts/odd-folder/features.json"; got != want {
		t.Errorf("file of realName = %q, want %q", got, want)
	}
	if !hosts.has("vpsNixos") || hosts.has("iso") {
		t.Errorf("has() disagrees with the discovered set: %v", hosts.order)
	}
}

func TestDiscoverHostsNone(t *testing.T) {
	if _, err := discoverHosts(t.TempDir()); err == nil {
		t.Error("a repo without any host feature list must be an error")
	}
}

// A save replaces the file in one step and leaves nothing else behind.
func TestWriteFeaturesReplacesTheFileCleanly(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "features.json")
	if err := os.WriteFile(path, []byte("[]\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	want := []string{"niri", "git"}
	if err := writeFeatures(path, want); err != nil {
		t.Fatal(err)
	}
	got, err := readFeatures(path)
	if err != nil || !reflect.DeepEqual(got, want) {
		t.Errorf("read back %v, %v; want %v", got, err, want)
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 {
		t.Errorf("the directory holds %d entries, want only features.json", len(entries))
	}
	if st, _ := os.Stat(path); st.Mode().Perm() != 0o600 {
		t.Errorf("mode = %v, want the file's own 0600 kept", st.Mode().Perm())
	}
}

// The old shape ({"system": …, "users": …}) is a clear error, not an empty list.
func TestParseFeaturesRejectsTheOldShape(t *testing.T) {
	_, err := parseFeatures([]byte(`{"system": ["nix"], "users": {"wiktor": ["git"]}}`))
	if err == nil || !strings.Contains(err.Error(), "JSON array") {
		t.Errorf("err = %v, want it to say a JSON array is expected", err)
	}
}

func TestIndexSources(t *testing.T) {
	repo := writeTree(t, map[string]string{
		"modules/features/programming/git/git.nix":  "{\n  flake.featureMeta.git = {kind = \"cli\";};\n}\n",
		"modules/features/programming/git/notes.md": "# git\n",
		// One file may declare several features; quoted names count too.
		"modules/features/apps/t3code/t3code.nix": "{\n  flake.featureMeta.t3code = {};\n  flake.featureMeta.\"t3code-server\" = {};\n}\n",
		"modules/features/zram/zram.nix":          "{\n  flake.featureMeta.zram = {};\n}\n",
		"modules/features/personal-snippets.nix":  "{\n  flake.featureMeta.personal-snippets = {};\n}\n",
	})
	got := indexSources(repo)
	want := map[string]featureSource{
		"git": {
			File:  "modules/features/programming/git/git.nix",
			Notes: "modules/features/programming/git/notes.md",
			Group: "programming",
		},
		"t3code":            {File: "modules/features/apps/t3code/t3code.nix", Group: "apps"},
		"t3code-server":     {File: "modules/features/apps/t3code/t3code.nix", Group: "apps"},
		"zram":              {File: "modules/features/zram/zram.nix"},
		"personal-snippets": {File: "modules/features/personal-snippets.nix"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("indexSources =\n %+v\nwant\n %+v", got, want)
	}
}
