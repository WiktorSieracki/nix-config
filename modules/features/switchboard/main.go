// Command switchboard is a TUI for managing the per-host feature lists of
// this nix-config. Real hosts keep their enabled features in
// modules/hosts/<host>/features.json (ADR 0003); Switchboard edits those data
// files — never .nix — and always writes the full transitive closure of
// `requires`, because the loader hard-fails on gaps (ADR 0002).
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

const version = "0.2.0"

func defaultFlake() string {
	if v := os.Getenv("SWITCHBOARD_FLAKE"); v != "" {
		return v
	}
	return "~/.config/nix-config"
}

func expandUser(path string) string {
	if path == "~" || strings.HasPrefix(path, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, strings.TrimPrefix(path, "~"))
		}
	}
	return path
}

func main() {
	fs := flag.NewFlagSet("switchboard", flag.ExitOnError)
	fs.SetOutput(os.Stdout)
	showVersion := fs.Bool("version", false, "print version and exit")
	flake := fs.String("flake", defaultFlake(),
		"path to the nix-config repo (override with $SWITCHBOARD_FLAKE)")
	fs.Usage = func() {
		fmt.Fprintln(fs.Output(), "usage: switchboard [--flake PATH] [--version]")
		fmt.Fprintln(fs.Output(), "TUI for managing NixOS host feature lists (features.json).")
		fs.PrintDefaults()
	}
	// flag.ExitOnError exits 0 on -h/--help — required by the Próba (no TTY).
	fs.Parse(os.Args[1:])

	if *showVersion {
		fmt.Printf("switchboard %s\n", version)
		return
	}

	repo, err := filepath.Abs(expandUser(*flake))
	if err != nil {
		fatal(err.Error())
	}
	if st, err := os.Stat(filepath.Join(repo, "flake.nix")); err != nil || st.IsDir() {
		fatal(fmt.Sprintf("no flake.nix in %s (use --flake or $SWITCHBOARD_FLAKE)", repo))
	}
	var missing []string
	for _, host := range hostOrder {
		if _, err := os.Stat(featuresPath(repo, host)); err != nil {
			missing = append(missing, featuresPath(repo, host))
		}
	}
	if len(missing) > 0 {
		fatal("missing host feature lists: " + strings.Join(missing, ", "))
	}

	if _, err := tea.NewProgram(newModel(repo), tea.WithAltScreen()).Run(); err != nil {
		fatal(err.Error())
	}
}

func fatal(msg string) {
	fmt.Fprintln(os.Stderr, "switchboard: "+msg)
	os.Exit(1)
}
