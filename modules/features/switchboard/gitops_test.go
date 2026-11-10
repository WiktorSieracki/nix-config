package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// git runs a git command in repo and returns its trimmed output.
func git(t *testing.T, repo string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = repo
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %s: %v\n%s", strings.Join(args, " "), err, out)
	}
	return strings.TrimSpace(string(out))
}

func write(t *testing.T, repo, name, content string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(repo, name), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

// newRepo makes a throwaway repository holding one commit with flake.lock and
// an unrelated file. The identity comes from the environment so the test needs
// no ~/.gitconfig (there is none in the Nix build sandbox).
func newRepo(t *testing.T) string {
	t.Helper()
	t.Setenv("HOME", t.TempDir())
	t.Setenv("GIT_CONFIG_GLOBAL", os.DevNull)
	t.Setenv("GIT_CONFIG_SYSTEM", os.DevNull)
	for _, k := range []string{"GIT_AUTHOR_NAME", "GIT_COMMITTER_NAME"} {
		t.Setenv(k, "Switchboard Test")
	}
	for _, k := range []string{"GIT_AUTHOR_EMAIL", "GIT_COMMITTER_EMAIL"} {
		t.Setenv(k, "switchboard@example.invalid")
	}

	repo := t.TempDir()
	git(t, repo, "init", "-q", "-b", "main")
	write(t, repo, "flake.lock", "lock v1\n")
	write(t, repo, "other.nix", "other v1\n")
	git(t, repo, "add", "--", "flake.lock", "other.nix")
	git(t, repo, "commit", "-q", "-m", "initial")
	return repo
}

// The commit offer must take exactly the files Switchboard touched. Whatever
// else sits in the index is the user's work in progress and stays there.
func TestGitCommitLeavesOtherStagedChangesAlone(t *testing.T) {
	repo := newRepo(t)
	write(t, repo, "other.nix", "other v2 (work in progress)\n")
	git(t, repo, "add", "--", "other.nix")
	write(t, repo, "flake.lock", "lock v2\n")

	if out, err := gitCommit(repo, []string{"flake.lock"}, "switchboard: update flake inputs"); err != nil {
		t.Fatalf("gitCommit: %v\n%s", err, out)
	}

	if got := git(t, repo, "show", "--name-only", "--format=", "HEAD"); got != "flake.lock" {
		t.Errorf("commit touched %q, want only flake.lock", got)
	}
	if got := git(t, repo, "diff", "--cached", "--name-only"); got != "other.nix" {
		t.Errorf("staged after commit = %q, want other.nix still staged", got)
	}
	if got := git(t, repo, "log", "-1", "--format=%s"); got != "switchboard: update flake inputs" {
		t.Errorf("subject = %q", got)
	}
}

// A file Switchboard creates (a host's first features.json) is untracked, so
// the commit has to add it before it can name it.
func TestGitCommitAddsUntrackedPath(t *testing.T) {
	repo := newRepo(t)
	write(t, repo, "features.json", "{}\n")

	if out, err := gitCommit(repo, []string{"features.json"}, "switchboard: add host"); err != nil {
		t.Fatalf("gitCommit: %v\n%s", err, out)
	}
	if got := git(t, repo, "show", "--name-only", "--format=", "HEAD"); got != "features.json" {
		t.Errorf("commit touched %q, want only features.json", got)
	}
}
