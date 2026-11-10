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
	styleBlue   = lipgloss.NewStyle().Foreground(lipgloss.Color("4"))
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
	hosts    hostSet
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
	origSpec   HostSpec
	spec       HostSpec // per-section order preserved for the file
	sections   []string // "system" + logins; the grid edits sections[section]
	section    int
	meta       map[string]FeatureMeta
	hmNames    map[string]bool // features with a home-manager part
	metaLoaded bool
	metaErr    string
	search     textinput.Model
	searching  bool
	cursor     int
	grid       Grid
	cellWidth  int

	// confirm
	newSpec HostSpec

	fin finale
}

func newModel(repo string, hosts hostSet) model {
	hostname, _ := os.Hostname()
	search := textinput.New()
	search.Prompt = "/"
	return model{repo: repo, hosts: hosts, hostname: hostname, keep: "3", search: search}
}

func (m model) Init() tea.Cmd { return nil }

// ── messages ────────────────────────────────────────────────────────────────

type metaLoadedMsg struct {
	meta    map[string]FeatureMeta
	hmNames map[string]bool
	err     error
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
		cat, err := loadCatalog(repo)
		return metaLoadedMsg{meta: cat.Meta, hmNames: cat.HMNames, err: err}
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
		m.hmNames = msg.hmNames
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
		local := m.hosts.has(m.hostname)
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

// The home list is every host, then the two maintenance items.
func (m model) homeUpdateIdx() int { return len(m.hosts.order) }
func (m model) homeCleanIdx() int  { return len(m.hosts.order) + 1 }

func (m model) handleHomeKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "q", "esc":
		return m, tea.Quit
	case "j", "down":
		if m.homeCursor < m.homeCleanIdx() {
			m.homeCursor++
		}
	case "k", "up":
		if m.homeCursor > 0 {
			m.homeCursor--
		}
	case "G":
		m.homeCursor = m.homeCleanIdx()
	case "enter", " ", "l":
		switch {
		case m.homeCursor < len(m.hosts.order):
			return m.enterHost(m.hosts.order[m.homeCursor])
		case m.homeCursor == m.homeUpdateIdx():
			data, err := os.ReadFile(filepath.Join(m.repo, "flake.lock"))
			if err != nil {
				m.setStatus("reading flake.lock: "+err.Error(), statusError)
				return m, nil
			}
			m.lockBefore = data
			return m, runInTerminal(m.repo, "flake-update", []string{"nix", "flake", "update"})
		case m.homeCursor == m.homeCleanIdx():
			m.editKeep = true
		}
	}
	return m, nil
}

func (m model) enterHost(host string) (tea.Model, tea.Cmd) {
	spec, err := readSpec(m.hosts.path(m.repo, host))
	if err != nil {
		m.setStatus(err.Error(), statusError)
		return m, nil
	}
	m.host = host
	m.origSpec = spec
	m.spec = spec.Clone()
	m.sections = spec.Sections()
	m.section = 0
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

// sectionName is the current section key ("system" or a login).
func (m model) sectionName() string { return m.sections[m.section] }

// enabled is the working feature list of the current section.
func (m model) enabled() []string { return m.spec.Get(m.sectionName()) }

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
	case "tab", "]":
		if len(m.sections) > 1 {
			m.switchSection((m.section + 1) % len(m.sections))
		}
	case "shift+tab", "[":
		if len(m.sections) > 1 {
			m.switchSection((m.section - 1 + len(m.sections)) % len(m.sections))
		}
	case " ":
		m.toggle(m.grid.NameAt(m.cursor))
	case "enter":
		return m.review()
	}
	return m, nil
}

// switchSection changes the edited section, keeping the cursor on the same
// feature (the catalog is shared across sections, so it's almost always there).
func (m *model) switchSection(section int) {
	name := m.grid.NameAt(m.cursor)
	m.section = section
	m.status = ""
	m.rebuildGrid()
	if idx := m.grid.IndexOf(name); idx >= 0 {
		m.cursor = idx
	}
}

func (m *model) toggle(name string) {
	if name == "" || !m.metaLoaded {
		return
	}
	// The rules (requires closure, refusals) live in rules.go, shared with
	// the web UI.
	res := Toggle(Catalog{Meta: m.meta, HMNames: m.hmNames}, m.spec, m.sectionName(), name)
	m.spec = res.Spec
	level := statusInfo
	if res.Refused {
		level = statusWarn
	}
	m.setStatus(res.Message, level)
}

func (m model) review() (tea.Model, tea.Cmd) {
	if !m.metaLoaded {
		return m, nil
	}
	m.newSpec = m.spec.Clone()
	for _, s := range m.sections {
		m.newSpec.Set(s, ReconcileOrder(m.origSpec.Get(s), m.spec.Get(s)))
	}
	if SpecEqual(m.newSpec, m.origSpec) {
		m.setStatus("No changes.", statusInfo)
		return m, nil
	}
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
	if err := writeSpec(m.hosts.path(m.repo, m.host), m.newSpec); err != nil {
		m.setStatus("saving: "+err.Error(), statusError)
		return m, nil
	}
	file := m.hosts.files[m.host]
	diff := SpecDiffString(SpecDiff(m.origSpec, m.newSpec))
	local := m.host == m.hostname
	m.fin = finale{
		commitPaths: []string{file},
		commitMsg:   commitMessage(m.host, diff),
		commitReady: !local,
	}
	m.status = ""
	m.scr = scrFinale
	if local {
		m.fin.applyHost = m.host
		m.fin.body = fmt.Sprintf("Saved %s (%s).\n\nApply it on this machine with t (test) or s (switch).",
			file, diff)
		return m, nil
	}
	m.fin.verifyHost = m.host
	m.fin.body = fmt.Sprintf("Saved %s (%s).\n\nThis machine is not %s — running a dry-run build as an eval check.",
		file, diff, m.host)
	return m, runInTerminal(m.repo, "dry-run", dryRunCommand(m.repo, m.host))
}

func (m model) handleFinaleKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "q", "esc":
		// Pop to main: host editing state is stale after a save.
		m.scr = scrHome
		return m, nil
	case "t":
		if m.fin.applyHost != "" {
			return m, runInTerminal(m.repo, "test", applyCommand("test", m.repo))
		}
	case "s":
		if m.fin.applyHost != "" {
			return m, runInTerminal(m.repo, "switch", applyCommand("switch", m.repo))
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
	groups := BuildGroups(m.meta, m.enabled(), m.search.Value())
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
	return contains(m.enabled(), name)
}

// isSystemProvided reports whether name is reachable in a user section only
// because `system` already enables it — not because this user's own list
// does. Lets the grid show "you already have this, via system" without
// implying the user owns it (toggling it still adds it explicitly to the
// user's own list, same as any other feature).
func (m model) isSystemProvided(name string) bool {
	return m.sectionName() != sectionSystem &&
		contains(m.spec.System, name) &&
		!m.isEnabled(name)
}

func (m *model) setStatus(s string, level int) {
	m.status = s
	m.statusLevel = level
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
	for i, h := range m.hosts.order {
		item(i, h)
	}
	lines = append(lines, "", styleHeader.Render("Maintenance"))
	item(m.homeUpdateIdx(), "Update flake")
	clean := "Clean — nh clean all --keep " + m.keep
	if m.editKeep {
		cursorLine = len(lines)
		lines = append(lines,
			styleCursor.Render("> Clean — nh clean all --keep ")+
				styleCursor.Underline(true).Render(m.keep+"▏"))
	} else {
		item(m.homeCleanIdx(), clean)
	}
	help := "j/k move · enter select · q quit"
	if m.editKeep {
		help = "digits edit --keep · enter run · esc cancel"
	}
	return m.frame(lines, cursorLine, help)
}

func (m model) viewHost() string {
	title := styleTitle.Render(m.host) +
		styleDim.Render(fmt.Sprintf("  %d enabled", len(m.enabled())))
	lines := []string{title}
	if len(m.sections) > 1 {
		lines = append(lines, m.viewSectionTabs())
	}
	if m.sectionName() != sectionSystem {
		lines = append(lines, styleBlue.Render("[s]")+styleDim.Render(" = enabled via system, not on this user's own list"))
	}
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
					systemProvided := m.isSystemProvided(name)
					switch {
					case m.isEnabled(name):
						box = "[x]"
					case systemProvided:
						box = "[s]"
					}
					cell := box + " " + name
					if pad := m.cellWidth - len(cell); pad > 0 {
						cell += strings.Repeat(" ", pad)
					}
					switch {
					case m.grid.Start(gi)+li == m.cursor:
						cursorLine = len(lines)
						cell = styleCursor.Render(cell)
					case systemProvided:
						cell = styleBlue.Render(cell)
					}
					b.WriteString(cell)
				}
				lines = append(lines, b.String())
			}
			lines = append(lines, "")
		}
	}
	return m.frame(lines, cursorLine,
		"space toggle · tab/[/] section · enter review · / search · h/j/k/l move · gg/G · esc back")
}

// viewSectionTabs renders the editable sections ("system" + each user login)
// as a tab bar, e.g. "[ system ]  wiktor   work", with the active one boxed
// so tab/[/] switching between accounts is visible, not just documented in
// the help line.
func (m model) viewSectionTabs() string {
	parts := make([]string, len(m.sections))
	for i, s := range m.sections {
		label := s
		if i == m.section {
			label = styleCursor.Render("[ " + label + " ]")
		} else {
			label = styleDim.Render("  " + label + "  ")
		}
		parts[i] = label
	}
	return strings.Join(parts, " ")
}

func (m model) viewConfirm() string {
	lines := []string{styleTitle.Render("Changes for " + m.host), ""}
	for _, s := range m.sections {
		added, removed := FeatureDiff(m.origSpec.Get(s), m.newSpec.Get(s))
		if len(added) == 0 && len(removed) == 0 {
			continue
		}
		lines = append(lines, styleHeader.Render(s))
		for _, f := range added {
			lines = append(lines, styleGreen.Render("+"+f))
		}
		for _, f := range removed {
			lines = append(lines, styleRed.Render("−"+f))
		}
		lines = append(lines, "")
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
