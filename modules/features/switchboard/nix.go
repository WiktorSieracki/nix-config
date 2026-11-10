package main

// Repo I/O: which hosts there are, their feature specs (features.json), the
// featureMeta catalog from `nix eval`, and where each feature's source lives.

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

// hostSet is the real hosts of a repo: the ones that keep their spec in a
// features.json. Image hosts (iso/vm/sandbox) keep inline specs and are not
// Switchboard's target.
type hostSet struct {
	order []string          // flake names, sorted
	files map[string]string // flake name → features.json, repo-relative, slash form
}

func (h hostSet) has(host string) bool { return h.files[host] != "" }

// path is the absolute path of a host's features.json.
func (h hostSet) path(repo, host string) string {
	return filepath.Join(repo, filepath.FromSlash(h.files[host]))
}

var hostSpecDecl = regexp.MustCompile(`hostSpecs\.("?)([A-Za-z0-9_-]+)("?)\s*=`)

// discoverHosts finds every modules/hosts/<dir>/features.json. A host's flake
// name is the one its default.nix registers (`hostSpecs.<name> = …`), falling
// back to the folder name camel-cased (desktop-nixos → desktopNixos).
func discoverHosts(repo string) (hostSet, error) {
	matches, err := filepath.Glob(filepath.Join(repo, "modules", "hosts", "*", "features.json"))
	if err != nil {
		return hostSet{}, err
	}
	hosts := hostSet{files: map[string]string{}}
	for _, m := range matches {
		dir := filepath.Dir(m)
		name := hostName(filepath.Base(dir))
		if data, err := os.ReadFile(filepath.Join(dir, "default.nix")); err == nil {
			if sub := hostSpecDecl.FindSubmatch(data); sub != nil {
				name = string(sub[2])
			}
		}
		rel, err := filepath.Rel(repo, m)
		if err != nil {
			return hostSet{}, err
		}
		hosts.files[name] = filepath.ToSlash(rel)
		hosts.order = append(hosts.order, name)
	}
	if len(hosts.order) == 0 {
		return hostSet{}, fmt.Errorf("no host feature lists (modules/hosts/*/features.json) in %s", repo)
	}
	sort.Strings(hosts.order)
	return hosts, nil
}

// hostName camel-cases a host folder name: desktop-nixos → desktopNixos.
func hostName(dir string) string {
	parts := strings.Split(dir, "-")
	for i := 1; i < len(parts); i++ {
		if parts[i] != "" {
			parts[i] = strings.ToUpper(parts[i][:1]) + parts[i][1:]
		}
	}
	return strings.Join(parts, "")
}

func readSpec(path string) (HostSpec, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return HostSpec{}, err
	}
	return parseSpec(data)
}

func parseSpec(data []byte) (HostSpec, error) {
	var spec HostSpec
	if err := json.Unmarshal(data, &spec); err != nil {
		return HostSpec{}, fmt.Errorf("parsing features.json: %w", err)
	}
	if spec.Users == nil {
		spec.Users = map[string][]string{}
	}
	return spec, nil
}

// writeSpec replaces the file in one step — a sibling written in full, then
// renamed over it — so nothing reading it meanwhile (the other UI, a `nix
// eval`) ever sees half a list.
func writeSpec(path string, spec HostSpec) error {
	mode := os.FileMode(0o644)
	if st, err := os.Stat(path); err == nil {
		mode = st.Mode().Perm()
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".features-*.json.tmp")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name()) // a no-op once it has been renamed
	if _, err := tmp.Write(MarshalSpec(spec)); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(mode); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), path)
}

func parseMeta(data []byte) (map[string]FeatureMeta, error) {
	var meta map[string]FeatureMeta
	if err := json.Unmarshal(data, &meta); err != nil {
		return nil, fmt.Errorf("parsing featureMeta: %w", err)
	}
	return meta, nil
}

func parseNames(data []byte) (map[string]bool, error) {
	var names []string
	if err := json.Unmarshal(data, &names); err != nil {
		return nil, fmt.Errorf("parsing module names: %w", err)
	}
	set := make(map[string]bool, len(names))
	for _, n := range names {
		set[n] = true
	}
	return set, nil
}

const catalogTimeout = 5 * time.Minute

// loadCatalog asks the flake for featureMeta and for the names of the
// home-manager modules. The latter matters because a feature with a
// home-manager part may not sit in `system` (its HM half would attach to
// nobody — the loader hard-fails on it, so the UIs refuse it already).
func loadCatalog(repo string) (Catalog, error) {
	// Seconds normally; minutes when inputs have to be fetched first. A hung
	// eval must not hold up whoever waits on the catalog forever.
	ctx, cancel := context.WithTimeout(context.Background(), catalogTimeout)
	defer cancel()
	evalJSON := func(attr, apply string) ([]byte, error) {
		args := []string{"eval", repo + "#" + attr, "--json"}
		if apply != "" {
			args = append(args, "--apply", apply)
		}
		out, err := exec.CommandContext(ctx, "nix", args...).Output()
		if ctx.Err() != nil {
			return nil, fmt.Errorf("nix eval %s did not finish within %s", attr, catalogTimeout)
		}
		if err != nil {
			msg := err.Error()
			var ee *exec.ExitError
			if errors.As(err, &ee) && len(ee.Stderr) > 0 {
				msg = tail(string(ee.Stderr), 300)
			}
			return nil, fmt.Errorf("nix eval %s failed: %s", attr, msg)
		}
		return out, nil
	}
	out, err := evalJSON("featureMeta", "")
	if err != nil {
		return Catalog{}, err
	}
	meta, err := parseMeta(out)
	if err != nil {
		return Catalog{}, err
	}
	out, err = evalJSON("modules.homeManager", "builtins.attrNames")
	if err != nil {
		return Catalog{}, err
	}
	hmNames, err := parseNames(out)
	if err != nil {
		return Catalog{}, err
	}
	return Catalog{Meta: meta, HMNames: hmNames}, nil
}

// featureSource is where a feature lives in the repo (all repo-relative, slash
// form). Display only.
type featureSource struct {
	File  string // the .nix file declaring its featureMeta
	Notes string // its feature notes, when the folder has a notes.md
	Group string // category folder (programming, apps, …); "" at the top level
}

var featureMetaDecl = regexp.MustCompile(`featureMeta\.("?)([A-Za-z0-9_-]+)("?)\s*=`)

// indexSources maps feature names to their source by scanning
// modules/features for `featureMeta.<name> =` declarations. Best effort: a
// feature declared some other way simply has no entry.
func indexSources(repo string) map[string]featureSource {
	root := filepath.Join(repo, "modules", "features")
	out := map[string]featureSource{}
	filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || filepath.Ext(path) != ".nix" {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return nil
		}
		// features/<group>/<feature>/<file>.nix — anything shallower has no group.
		parts := strings.Split(filepath.ToSlash(rel), "/")
		src := featureSource{File: "modules/features/" + filepath.ToSlash(rel)}
		if len(parts) >= 3 {
			src.Group = parts[0]
		}
		if len(parts) >= 2 {
			if _, err := os.Stat(filepath.Join(filepath.Dir(path), "notes.md")); err == nil {
				src.Notes = "modules/features/" + strings.Join(parts[:len(parts)-1], "/") + "/notes.md"
			}
		}
		for _, sub := range featureMetaDecl.FindAllSubmatch(data, -1) {
			out[string(sub[2])] = src
		}
		return nil
	})
	return out
}

// applyCommand activates this machine's own host: `nh os test` or `nh os switch`.
func applyCommand(action, repo string) []string {
	return []string{"nh", "os", action, repo}
}

// dryRunCommand evaluates a host's whole system without building it — the
// check for a host this machine cannot activate.
func dryRunCommand(repo, host string) []string {
	target := fmt.Sprintf("%s#nixosConfigurations.%s.config.system.build.toplevel", repo, host)
	return []string{"nix", "build", target, "--dry-run"}
}
