package main

// Git plumbing for the one-key commit offer: `git add` the touched data files
// and commit exactly those with a `switchboard: …` message. Never pushes.

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
	// The pathspec limits the commit to these files. Without it git commits
	// the whole index, so anything the user had staged for their own next
	// commit went out under a `switchboard: …` subject.
	commit := exec.Command("git", append([]string{"commit", "-m", message, "--"}, paths...)...)
	commit.Dir = repo
	out2, err := commit.CombinedOutput()
	return strings.TrimSpace(string(out) + string(out2)), err
}

// commitMessage is the subject of a feature-list commit:
// "switchboard: desktopNixos system: +a -b · wiktor: +c".
func commitMessage(host, diff string) string {
	return "switchboard: " + host + " " + diff
}

// headSpec is a host's feature list as of the last commit — what `git commit`
// would be diffed against.
func headSpec(repo, file string) (HostSpec, error) {
	show := exec.Command("git", "show", "HEAD:"+file)
	show.Dir = repo
	out, err := show.Output()
	if err != nil {
		return HostSpec{}, err
	}
	return parseSpec(out)
}

// tail returns at most the last n characters of s (for compact error toasts).
func tail(s string, n int) string {
	s = strings.TrimSpace(s)
	if len(s) > n {
		return s[len(s)-n:]
	}
	return s
}
