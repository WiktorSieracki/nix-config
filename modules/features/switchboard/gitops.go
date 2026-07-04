package main

// Git plumbing for the one-key commit offer: `git add` the touched data files
// and commit with a `switchboard: …` message. Never pushes.

import (
	"os/exec"
	"strings"
)

func gitCommit(repo string, paths []string, message string) (string, error) {
	add := exec.Command("git", append([]string{"add", "--"}, paths...)...)
	add.Dir = repo
	out, err := add.CombinedOutput()
	if err != nil {
		return string(out), err
	}
	commit := exec.Command("git", "commit", "-m", message)
	commit.Dir = repo
	out2, err := commit.CombinedOutput()
	return strings.TrimSpace(string(out) + string(out2)), err
}

// tail returns at most the last n characters of s (for compact error toasts).
func tail(s string, n int) string {
	s = strings.TrimSpace(s)
	if len(s) > n {
		return s[len(s)-n:]
	}
	return s
}
