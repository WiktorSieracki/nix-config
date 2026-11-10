// Command switchboard manages the per-host feature lists of this nix-config,
// as a TUI (the default) or as a web UI in the browser (`switchboard web`).
// Real hosts keep their enabled features in
// modules/hosts/<host>/features.json; Switchboard edits those data
// files — never .nix — and always writes the full transitive closure of
// `requires`, because the loader hard-fails on gaps.
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

const version = "0.3.0"

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

const flakeUsage = "path to the nix-config repo (override with $SWITCHBOARD_FLAKE)"

func main() {
	fs := flag.NewFlagSet("switchboard", flag.ExitOnError)
	fs.SetOutput(os.Stdout)
	showVersion := fs.Bool("version", false, "print version and exit")
	flake := fs.String("flake", defaultFlake(), flakeUsage)
	fs.Usage = func() {
		fmt.Fprintln(fs.Output(), "usage: switchboard [--flake PATH] [--version]")
		fmt.Fprintln(fs.Output(), "       switchboard web [--flake PATH] [--addr HOST:PORT] [--no-open] [--idle-timeout D]")
		fmt.Fprintln(fs.Output(), "Manage NixOS host feature lists (features.json): a TUI, or `web` for the same in a browser.")
		fs.PrintDefaults()
	}
	// flag.ExitOnError exits 0 on -h/--help — required by the feature test (no TTY).
	fs.Parse(os.Args[1:])

	if *showVersion {
		fmt.Printf("switchboard %s\n", version)
		return
	}

	var web *webOptions
	switch fs.Arg(0) {
	case "":
	case "web":
		web = parseWebOptions(fs.Args()[1:], flake)
	default:
		fatal(fmt.Sprintf("unknown command %q (the only one is `web`)", fs.Arg(0)))
	}

	repo, err := filepath.Abs(expandUser(*flake))
	if err != nil {
		fatal(err.Error())
	}
	if st, err := os.Stat(filepath.Join(repo, "flake.nix")); err != nil || st.IsDir() {
		fatal(fmt.Sprintf("no flake.nix in %s (use --flake or $SWITCHBOARD_FLAKE)", repo))
	}
	hosts, err := discoverHosts(repo)
	if err != nil {
		fatal(err.Error())
	}

	if web != nil {
		if err := runWeb(repo, hosts, *web); err != nil {
			fatal(err.Error())
		}
		return
	}
	if _, err := tea.NewProgram(newModel(repo, hosts), tea.WithAltScreen()).Run(); err != nil {
		fatal(err.Error())
	}
}

func fatal(msg string) {
	fmt.Fprintln(os.Stderr, "switchboard: "+msg)
	os.Exit(1)
}
