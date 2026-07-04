package main

// The bubbletea TUI: terminal-native (no painted backgrounds, default
// terminal colors, one ANSI accent), vim motions everywhere, a multi-column
// feature grid grouped by kind, and a single dim help line at the bottom.

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type screen int

const (
	scrHome screen = iota
	scrHost
	scrConfirm
	scrFinale
)

const (
	statusInfo = iota
	statusWarn
	statusError
)

var (
	styleTitle  = lipgloss.NewStyle().Bold(true)
	styleDim    = lipgloss.NewStyle().Faint(true)
	styleHeader = lipgloss.NewStyle().Bold(true)
	styleCursor = lipgloss.NewStyle().Foreground(lipgloss.Color("6")).Bold(true)
	styleGreen  = lipgloss.NewStyle().Foreground(lipgloss.Color("2"))
	styleRed    = lipgloss.NewStyle().Foreground(lipgloss.Color("1"))
	styleYellow = lipgloss.NewStyle().Foreground(lipgloss.Color("3"))
)

// finale is the post-save / post-update state: apply locally with
// nh os test/switch, or verify a foreign host with a dry-run build;
// optionally commit.
type finale struct {
	body        string
	applyHost   string // host name if this machine can apply it ("" otherwise)
	verifyHost  string // foreign host to dry-run build for ("" otherwise)
	commitPaths []string
	commitMsg   string
	commitReady bool
}

type model struct {
	repo     string
	hostname string
	width    int
	height   int
	scr      screen

	status      string
	statusLevel int
	gPending    bool

	// home
	homeCursor int
	keep       string // --keep value for `nh clean all`
	editKeep   bool
	lockBefore []byte

	// host (feature grid)
	host       string
	original   []string
	enabled    []string // order preserved for the file
	meta       map[string]FeatureMeta
	metaLoaded bool
	metaErr    string
	search     textinput.Model
	searching  bool
	cursor     int
	grid       Grid
	cellWidth  int

	// confirm
	newList []string

	fin finale
}

func newModel(repo string) model {
	hostname, _ := os.Hostname()
	search := textinput.New()
	search.Prompt = "/"
	return model{repo: repo, hostname: hostname, keep: "3", search: search}
}

func (m model) Init() tea.Cmd { return nil }

// ── messages ────────────────────────────────────────────────────────────────

type metaLoadedMsg struct {
	meta map[string]FeatureMeta
	err  error
}

type execDoneMsg struct {
	tag  string
	code int
}

type gitDoneMsg struct {
	out string
	err error
}

func loadMeta(repo string) tea.Cmd {
	return func() tea.Msg {
		out, err := exec.Command("nix", "eval", repo+"#featureMeta", "--json").Output()
		if err != nil {
			msg := err.Error()
			var ee *exec.ExitError
			if errors.As(err, &ee) && len(ee.Stderr) > 0 {
				msg = tail(string(ee.Stderr), 300)
			}
			return metaLoadedMsg{err: fmt.Errorf("nix eval featureMeta failed: %s", msg)}
		}
		meta, err := parseMeta(out)
		return metaLoadedMsg{meta: meta, err: err}
	}
}

// runInTerminal suspends the TUI and hands the real terminal to cmd (streamed
// output), then pauses until Enter so the output stays readable — bubbletea
// re-enters the alternate screen immediately otherwise (same fix as the
// retired Textual version).
func runInTerminal(repo, tag string, args []string) tea.Cmd {
	line := ShQuote(args)
	script := fmt.Sprintf(
		"printf '\\n$ %%s\\n' %s\n%s\nrc=$?\n"+
			"printf '\\n[switchboard] exit code %%s — press Enter to return ' \"$rc\"\n"+
			"read -r _ || true\nexit $rc",
		ShQuote([]string{line}), line)
	cmd := exec.Command("sh", "-c", script)
	cmd.Dir = repo
	return tea.ExecProcess(cmd, func(err error) tea.Msg {
		return execDoneMsg{tag: tag, code: exitCode(err)}
	})
}

func exitCode(err error) int {
	if err == nil {
		return 0
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		return ee.ExitCode()
	}
	return -1
}

func commitCmd(repo string, paths []string, message string) tea.Cmd {
	return func() tea.Msg {
		out, err := gitCommit(repo, paths, message)
		return gitDoneMsg{out: out, err: err}
	}
}

// ── update ──────────────────────────────────────────────────────────────────

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.rebuildGrid()
		return m, nil

	case metaLoadedMsg:
		if msg.err != nil {
			m.metaErr = msg.err.Error()
			return m, nil
		}
		m.meta = msg.meta
		m.metaLoaded = true
		m.metaErr = ""
		m.rebuildGrid()
		return m, nil

	case execDoneMsg:
		return m.handleExecDone(msg)

	case gitDoneMsg:
		if msg.err == nil {
			m.setStatus("Committed: "+m.fin.commitMsg, statusInfo)
			m.fin.commitReady = false
		} else {
			m.setStatus("git commit failed: "+tail(msg.out, 300), statusError)
		}
		return m, nil

	case tea.KeyMsg:
		return m.handleKey(msg)
	}
	return m, nil
}

func (m model) handleExecDone(msg execDoneMsg) (tea.Model, tea.Cmd) {
	switch msg.tag {
	case "clean":
		if msg.code == 0 {
			m.setStatus(fmt.Sprintf("nh clean all --keep %s succeeded.", m.keep), statusInfo)
		} else {
			m.setStatus(fmt.Sprintf("nh clean all failed (exit %d).", msg.code), statusError)
		}

	case "flake-update":
		if msg.code != 0 {
			m.setStatus(fmt.Sprintf("nix flake update failed (exit %d).", msg.code), statusError)
			return m, nil
		}
		after, err := os.ReadFile(filepath.Join(m.repo, "flake.lock"))
		if err != nil {
			m.setStatus("reading flake.lock: "+err.Error(), statusError)
			return m, nil
		}
		changes, err := LockDiff(m.lockBefore, after)
		if err != nil {
			m.setStatus(err.Error(), statusError)
			return m, nil
		}
		if len(changes) == 0 {
			m.setStatus("All flake inputs already up to date.", statusInfo)
			return m, nil
		}
		local := hostFiles[m.hostname] != ""
		body := "Updated flake inputs:\n\n" + strings.Join(changes, "\n")
		if local {
			body += "\n\nApply on this machine with t (test) or s (switch)."
		} else {
			body += fmt.Sprintf("\n\nThis machine (%s) is not a managed host.", m.hostname)
		}
		applyHost := ""
		if local {
			applyHost = m.hostname
		}
		m.fin = finale{
			body:        body,
			applyHost:   applyHost,
			commitPaths: []string{"flake.lock"},
			commitMsg:   "switchboard: update flake inputs",
			commitReady: !local,
		}
		m.scr = scrFinale

	case "dry-run":
		if msg.code == 0 {
			m.setStatus("Saved — apply it on "+m.fin.verifyHost+".", statusInfo)
		} else {
			m.setStatus(fmt.Sprintf(
				"Saved, but the dry-run build for %s failed (exit %d) — check the config before applying.",
				m.fin.verifyHost, msg.code), statusError)
		}

	case "test":
		if msg.code == 0 {
			m.setStatus("nh os test succeeded (no commit after a test).", statusInfo)
		} else {
			m.setStatus(fmt.Sprintf("nh os test failed (exit %d).", msg.code), statusError)
		}

	case "switch":
		if msg.code == 0 {
			m.fin.commitReady = true
			m.setStatus("nh os switch succeeded — press c to commit.", statusInfo)
		} else {
			m.setStatus(fmt.Sprintf("nh os switch failed (exit %d).", msg.code), statusError)
		}
	}
	return m, nil
}

// ── key handling ────────────────────────────────────────────────────────────

func (m model) handleKey(k tea.KeyMsg) (tea.Model, tea.Cmd) {
	key := k.String()
	if key == "ctrl+c" {
		return m, tea.Quit
	}

	// Live search captures every key while active.
	if m.scr == scrHost && m.searching {
		switch key {
		case "esc":
			m.searching = false
			m.search.SetValue("")
			m.search.Blur()
			m.cursor = 0
			m.rebuildGrid()
		case "enter":
			m.searching = false
			m.search.Blur()
		default:
			var cmd tea.Cmd
			m.search, cmd = m.search.Update(k)
			m.cursor = 0
			m.rebuildGrid()
			return m, cmd
		}
		return m, nil
	}

	// In-place editing of the --keep number on the home screen.
	if m.scr == scrHome && m.editKeep {
		switch {
		case key == "esc":
			m.editKeep = false
		case key == "enter":
			if m.keep == "" {
				m.keep = "3"
			}
			m.editKeep = false
			return m, runInTerminal(m.repo, "clean",
				[]string{"nh", "clean", "all", "--keep", m.keep})
		case key == "backspace":
			if len(m.keep) > 0 {
				m.keep = m.keep[:len(m.keep)-1]
			}
		case len(key) == 1 && key[0] >= '0' && key[0] <= '9':
			if len(m.keep) < 4 {
				m.keep += key
			}
		}
		return m, nil
	}

	// gg (vim: go to top) needs a pending first g.
	if key == "g" {
		if m.gPending {
			m.gPending = false
			return m.moveTop(), nil
		}
		m.gPending = true
		return m, nil
	}
	m.gPending = false

	switch m.scr {
	case scrHome:
		return m.handleHomeKey(key)
	case scrHost:
		return m.handleHostKey(key)
	case scrConfirm:
		return m.handleConfirmKey(key)
	case scrFinale:
		return m.handleFinaleKey(key)
	}
	return m, nil
}

func (m model) moveTop() model {
	switch m.scr {
	case scrHome:
		m.homeCursor = 0
	case scrHost:
		m.cursor = 0
	}
	return m
}

const homeItems = 4 // desktopNixos, laptopNixos, Update flake, Clean

func (m model) handleHomeKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "q", "esc":
		return m, tea.Quit
	case "j", "down":
		if m.homeCursor < homeItems-1 {
			m.homeCursor++
		}
	case "k", "up":
		if m.homeCursor > 0 {
			m.homeCursor--
		}
	case "G":
		m.homeCursor = homeItems - 1
	case "enter", " ", "l":
		switch m.homeCursor {
		case 0, 1:
			return m.enterHost(hostOrder[m.homeCursor])
		case 2: // Update flake
			data, err := os.ReadFile(filepath.Join(m.repo, "flake.lock"))
			if err != nil {
				m.setStatus("reading flake.lock: "+err.Error(), statusError)
				return m, nil
			}
			m.lockBefore = data
			return m, runInTerminal(m.repo, "flake-update", []string{"nix", "flake", "update"})
		case 3: // Clean
			m.editKeep = true
		}
	}
	return m, nil
}

func (m model) enterHost(host string) (tea.Model, tea.Cmd) {
	features, err := readFeatures(m.repo, host)
	if err != nil {
		m.setStatus(err.Error(), statusError)
		return m, nil
	}
	m.host = host
	m.original = features
	m.enabled = append([]string(nil), features...)
	m.metaLoaded = false
	m.metaErr = ""
	m.meta = nil
	m.cursor = 0
	m.search.SetValue("")
	m.searching = false
	m.status = ""
	m.scr = scrHost
	m.grid = Grid{}
	return m, loadMeta(m.repo)
}

func (m model) handleHostKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "q", "esc":
		if m.search.Value() != "" {
			m.search.SetValue("")
			m.cursor = 0
			m.rebuildGrid()
			return m, nil
		}
		m.scr = scrHome
		m.status = ""
	case "/":
		m.searching = true
		m.search.Focus()
		return m, textinput.Blink
	case "j", "down":
		m.cursor = m.grid.Down(m.cursor)
	case "k", "up":
		m.cursor = m.grid.Up(m.cursor)
	case "h", "left":
		m.cursor = m.grid.Left(m.cursor)
	case "l", "right":
		m.cursor = m.grid.Right(m.cursor)
	case "G":
		if m.grid.Total > 0 {
			m.cursor = m.grid.Total - 1
		}
	case " ":
		m.toggle(m.grid.NameAt(m.cursor))
	case "enter":
		return m.review()
	}
	return m, nil
}

func (m *model) toggle(name string) {
	if name == "" || !m.metaLoaded {
		return
	}
	if m.isEnabled(name) {
		m.disable(name)
	} else {
		m.enable(name)
	}
}

func (m *model) enable(name string) {
	var pulled []string
	for dep := range RequiresClosure(m.meta, []string{name}) {
		if dep != name && !m.isEnabled(dep) {
			pulled = append(pulled, dep)
		}
	}
	sort.Strings(pulled)
	m.enabled = append(m.enabled, name)
	m.enabled = append(m.enabled, pulled...) // the file gets the full closure
	if len(pulled) > 0 {
		m.setStatus(fmt.Sprintf("Also enabled (required by %s): %s",
			name, strings.Join(pulled, ", ")), statusInfo)
	} else {
		m.status = ""
	}
}

func (m *model) disable(name string) {
	dependents := Dependents(m.meta, m.enabled, name)
	if len(dependents) > 0 {
		m.setStatus(fmt.Sprintf("Cannot disable %s — required by: %s",
			name, strings.Join(dependents, ", ")), statusWarn)
		return
	}
	for i, f := range m.enabled {
		if f == name {
			m.enabled = append(m.enabled[:i], m.enabled[i+1:]...)
			break
		}
	}
	// Deps that were auto-pulled for `name` stay enabled on purpose.
	m.status = ""
}

func (m model) review() (tea.Model, tea.Cmd) {
	if !m.metaLoaded {
		return m, nil
	}
	newList := ReconcileOrder(m.original, m.enabled)
	if equal(newList, m.original) {
		m.setStatus("No changes.", statusInfo)
		return m, nil
	}
	m.newList = newList
	m.status = ""
	m.scr = scrConfirm
	return m, nil
}

func (m model) handleConfirmKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "q", "esc":
		m.scr = scrHost
		return m, nil
	case "enter", "y":
		return m.save()
	}
	return m, nil
}

func (m model) save() (tea.Model, tea.Cmd) {
	if err := writeFeatures(m.repo, m.host, m.newList); err != nil {
		m.setStatus("saving: "+err.Error(), statusError)
		return m, nil
	}
	added, removed := FeatureDiff(m.original, m.newList)
	diff := DiffString(added, removed)
	local := m.host == m.hostname
	m.fin = finale{
		commitPaths: []string{hostFiles[m.host]},
		commitMsg:   fmt.Sprintf("switchboard: %s %s", m.host, diff),
		commitReady: !local,
	}
	m.status = ""
	m.scr = scrFinale
	if local {
		m.fin.applyHost = m.host
		m.fin.body = fmt.Sprintf("Saved %s (%s).\n\nApply it on this machine with t (test) or s (switch).",
			hostFiles[m.host], diff)
		return m, nil
	}
	m.fin.verifyHost = m.host
	m.fin.body = fmt.Sprintf("Saved %s (%s).\n\nThis machine is not %s — running a dry-run build as an eval check.",
		hostFiles[m.host], diff, m.host)
	target := fmt.Sprintf("%s#nixosConfigurations.%s.config.system.build.toplevel", m.repo, m.host)
	return m, runInTerminal(m.repo, "dry-run", []string{"nix", "build", target, "--dry-run"})
}

func (m model) handleFinaleKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "q", "esc":
		// Pop to main: host editing state is stale after a save.
		m.scr = scrHome
		return m, nil
	case "t":
		if m.fin.applyHost != "" {
			return m, runInTerminal(m.repo, "test", []string{"nh", "os", "test", m.repo})
		}
	case "s":
		if m.fin.applyHost != "" {
			return m, runInTerminal(m.repo, "switch", []string{"nh", "os", "switch", m.repo})
		}
	case "c":
		if m.fin.commitReady {
			return m, commitCmd(m.repo, m.fin.commitPaths, m.fin.commitMsg)
		}
	}
	return m, nil
}

// ── grid plumbing ───────────────────────────────────────────────────────────

func (m *model) rebuildGrid() {
	if !m.metaLoaded {
		m.grid = Grid{}
		return
	}
	groups := BuildGroups(m.meta, m.enabled, m.search.Value())
	maxLen := 0
	for _, g := range groups {
		for _, item := range g.Items {
			if len(item) > maxLen {
				maxLen = len(item)
			}
		}
	}
	m.cellWidth = maxLen + 4 + 2 // "[x] " + gap
	cols := 1
	if m.width > 0 && m.cellWidth > 0 {
		if c := m.width / m.cellWidth; c > 1 {
			cols = c
		}
	}
	m.grid = BuildGrid(groups, cols)
	if m.cursor >= m.grid.Total {
		m.cursor = m.grid.Total - 1
	}
	if m.cursor < 0 {
		m.cursor = 0
	}
}

func (m model) isEnabled(name string) bool {
	for _, f := range m.enabled {
		if f == name {
			return true
		}
	}
	return false
}

func (m *model) setStatus(s string, level int) {
	m.status = s
	m.statusLevel = level
}

func equal(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// ── view ────────────────────────────────────────────────────────────────────

func (m model) View() string {
	switch m.scr {
	case scrHome:
		return m.viewHome()
	case scrHost:
		return m.viewHost()
	case scrConfirm:
		return m.viewConfirm()
	case scrFinale:
		return m.viewFinale()
	}
	return ""
}

func (m model) viewHome() string {
	lines := []string{
		styleTitle.Render("switchboard") + styleDim.Render("  "+m.repo),
		styleDim.Render("this machine: " + m.hostname),
		"",
		styleHeader.Render("Hosts"),
	}
	cursorLine := 0
	item := func(idx int, label string) {
		if idx == m.homeCursor {
			cursorLine = len(lines)
			lines = append(lines, styleCursor.Render("> "+label))
		} else {
			lines = append(lines, "  "+label)
		}
	}
	for i, h := range hostOrder {
		item(i, h)
	}
	lines = append(lines, "", styleHeader.Render("Maintenance"))
	item(2, "Update flake")
	clean := "Clean — nh clean all --keep " + m.keep
	if m.editKeep {
		cursorLine = len(lines)
		lines = append(lines,
			styleCursor.Render("> Clean — nh clean all --keep ")+
				styleCursor.Underline(true).Render(m.keep+"▏"))
	} else {
		item(3, clean)
	}
	help := "j/k move · enter select · q quit"
	if m.editKeep {
		help = "digits edit --keep · enter run · esc cancel"
	}
	return m.frame(lines, cursorLine, help)
}

func (m model) viewHost() string {
	title := styleTitle.Render(m.host) +
		styleDim.Render(fmt.Sprintf("  %d enabled", len(m.enabled)))
	lines := []string{title}
	if m.searching {
		lines = append(lines, m.search.View())
	} else if q := m.search.Value(); q != "" {
		lines = append(lines, styleDim.Render("filter: "+q+"  (esc clears)"))
	} else {
		lines = append(lines, "")
	}
	cursorLine := 0

	switch {
	case m.metaErr != "":
		lines = append(lines, styleRed.Render(m.metaErr))
	case !m.metaLoaded:
		lines = append(lines, styleDim.Render("loading featureMeta…"))
	case m.grid.Total == 0:
		lines = append(lines, styleDim.Render("no features match"))
	default:
		for gi, grp := range m.grid.Groups {
			lines = append(lines, styleHeader.Render(grp.Kind))
			occ := occupiedCols(grp)
			for row := 0; row < grp.Rows; row++ {
				var b strings.Builder
				for col := 0; col < occ; col++ {
					li := col*grp.Rows + row
					if li >= len(grp.Items) {
						continue
					}
					name := grp.Items[li]
					box := "[ ]"
					if m.isEnabled(name) {
						box = "[x]"
					}
					cell := box + " " + name
					if pad := m.cellWidth - len(cell); pad > 0 {
						cell += strings.Repeat(" ", pad)
					}
					if m.grid.Start(gi)+li == m.cursor {
						cursorLine = len(lines)
						cell = styleCursor.Render(cell)
					}
					b.WriteString(cell)
				}
				lines = append(lines, b.String())
			}
			lines = append(lines, "")
		}
	}
	return m.frame(lines, cursorLine,
		"space toggle · enter review · / search · h/j/k/l move · gg/G · esc back")
}

func (m model) viewConfirm() string {
	added, removed := FeatureDiff(m.original, m.newList)
	lines := []string{styleTitle.Render("Changes for " + m.host), ""}
	for _, f := range added {
		lines = append(lines, styleGreen.Render("+"+f))
	}
	for _, f := range removed {
		lines = append(lines, styleRed.Render("−"+f))
	}
	return m.frame(lines, 0, "enter save · esc back")
}

func (m model) viewFinale() string {
	lines := append([]string{styleTitle.Render("switchboard"), ""},
		strings.Split(m.fin.body, "\n")...)
	var keys []string
	if m.fin.applyHost != "" {
		keys = append(keys, "t test", "s switch")
	}
	if m.fin.commitReady {
		keys = append(keys, "c commit")
	}
	keys = append(keys, "esc done")
	return m.frame(lines, 0, strings.Join(keys, " · "))
}

// frame clips the content vertically around the cursor line and pins a status
// line plus a single dim help line at the bottom.
func (m model) frame(lines []string, cursorLine int, help string) string {
	status := m.status
	switch m.statusLevel {
	case statusWarn:
		status = styleYellow.Render(status)
	case statusError:
		status = styleRed.Render(status)
	}

	content := lines
	if m.height > 2 {
		avail := m.height - 2
		if len(lines) > avail {
			start := cursorLine - avail/2
			if start > len(lines)-avail {
				start = len(lines) - avail
			}
			if start < 0 {
				start = 0
			}
			content = lines[start : start+avail]
		} else {
			content = append([]string(nil), lines...)
			for len(content) < avail {
				content = append(content, "")
			}
		}
	}
	return strings.Join(content, "\n") + "\n" + status + "\n" + styleDim.Render(help)
}
