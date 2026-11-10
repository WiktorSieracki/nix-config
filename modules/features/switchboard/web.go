package main

// `switchboard web`: the feature lists in a browser. A small HTTP server on
// loopback serves an embedded page (web/) and a JSON API. Every rule the page
// applies is computed here, by the same functions the TUI uses (rules.go) —
// the page only draws.
//
// The server can rewrite the config and run `nh os switch`, so it is fenced
// four ways (web_test.go holds each to it): the connection must come from the
// user who started the server (peer.go — loopback is shared by every account
// on the machine), the Host header must be ours (DNS rebinding), writes must
// be same-origin, and every API call must carry the token only our own page
// was given.

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

//go:embed web
var webFiles embed.FS

const (
	defaultWebAddr = "127.0.0.1:7391"
	tokenHeader    = "X-Switchboard-Token"
	// Placeholder in web/index.html, swapped for the per-run token.
	tokenPlaceholder = "__SWITCHBOARD_TOKEN__"
	maxJobOutput     = 1 << 20
)

type webOptions struct {
	addr string
	open bool
	idle time.Duration
}

// parseWebOptions parses what follows `switchboard web`. --flake is accepted
// here as well, so it works on either side of the subcommand.
func parseWebOptions(args []string, flake *string) *webOptions {
	fs := flag.NewFlagSet("switchboard web", flag.ExitOnError)
	fs.SetOutput(os.Stdout)
	opts := &webOptions{}
	fs.StringVar(flake, "flake", *flake, flakeUsage)
	fs.StringVar(&opts.addr, "addr", defaultWebAddr, "loopback address to serve on")
	noOpen := fs.Bool("no-open", false, "do not open the browser")
	fs.DurationVar(&opts.idle, "idle-timeout", 30*time.Minute,
		"exit after this long without a request, e.g. 10m (0 = never)")
	fs.Usage = func() {
		fmt.Fprintln(fs.Output(), "usage: switchboard web [--flake PATH] [--addr HOST:PORT] [--no-open] [--idle-timeout D]")
		fmt.Fprintln(fs.Output(), "Serve the feature lists as a web UI on loopback and open it in the browser.")
		fs.PrintDefaults()
	}
	fs.Parse(args)
	opts.open = !*noOpen
	return opts
}

// runWeb serves until interrupted or idle. A second `switchboard web` finds
// the first one on the port and just opens the browser at it.
func runWeb(repo string, hosts hostSet, opts webOptions) error {
	if err := requireLoopback(opts.addr); err != nil {
		return err
	}
	ln, err := net.Listen("tcp", opts.addr)
	if err != nil {
		serving, ok := runningInstance(opts.addr)
		if !ok {
			return err
		}
		if serving != repo {
			return fmt.Errorf("switchboard web is already serving %s on %s — stop it, or give this one another --addr", serving, opts.addr)
		}
		url := "http://" + opts.addr + "/"
		fmt.Printf("switchboard web: already running at %s\n", url)
		if opts.open {
			openBrowser(url)
		}
		return nil
	}
	s, err := newWebServer(repo, hosts)
	if err != nil {
		return err
	}
	s.listenAddr = ln.Addr().String()
	srv := &http.Server{
		Handler:           s.handler(),
		ConnContext:       s.connContext,
		ReadHeaderTimeout: 10 * time.Second,
	}
	served := make(chan error, 1)
	go func() { served <- srv.Serve(ln) }()

	url := "http://" + s.listenAddr + "/"
	fmt.Printf("switchboard web: %s (Ctrl+C to stop)\n", url)
	if opts.open {
		openBrowser(url)
	}

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	tick := time.NewTicker(15 * time.Second)
	defer tick.Stop()
	for {
		select {
		case err := <-served:
			return err
		case <-sig:
			// Exiting closes the pipe a running job writes to. For a build
			// check that is the point; an activation it could stop half-way,
			// so that one is waited for.
			if done := s.applying(); done != nil {
				fmt.Println("switchboard web: waiting for the running nh job to finish (Ctrl+C again exits now, and may interrupt it)")
				select {
				case <-done:
				case <-sig:
				}
			}
			s.stopJob()
			return srv.Close()
		case <-tick.C:
			// An open page keeps asking for state, so "idle" means every
			// tab is gone. Started from the launcher there is no terminal
			// to Ctrl+C — this is what stops the server then.
			if opts.idle > 0 && s.idleFor() >= opts.idle {
				fmt.Println("switchboard web: no requests for " + opts.idle.String() + " — exiting")
				return srv.Close()
			}
		}
	}
}

// requireLoopback refuses any address other machines could reach: the page
// has no login, and whoever can load it can switch the system.
func requireLoopback(addr string) error {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return fmt.Errorf("--addr %q: %w", addr, err)
	}
	if host == "localhost" {
		return nil
	}
	if ip := net.ParseIP(host); ip == nil || !ip.IsLoopback() {
		return fmt.Errorf("--addr %q is not a loopback address — the web UI has no login; to reach it from another machine, forward the port over ssh", addr)
	}
	return nil
}

// runningInstance asks whatever holds addr whether it is a switchboard of
// this user's, and which repo it serves.
func runningInstance(addr string) (repo string, ok bool) {
	client := http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("http://" + addr + "/api/ping")
	if err != nil {
		return "", false
	}
	defer resp.Body.Close()
	var ping struct {
		App  string `json:"app"`
		Repo string `json:"repo"`
	}
	if resp.StatusCode != http.StatusOK || json.NewDecoder(resp.Body).Decode(&ping) != nil || ping.App != "switchboard" {
		return "", false
	}
	return ping.Repo, true
}

func openBrowser(url string) {
	cmd := exec.Command("xdg-open", url)
	if err := cmd.Start(); err != nil {
		fmt.Println("switchboard web: could not open a browser (" + err.Error() + ") — open the address above yourself")
		return
	}
	go cmd.Wait()
}

// ── server ──────────────────────────────────────────────────────────────────

type webServer struct {
	repo       string
	hosts      hostSet
	hostname   string
	uid        uint32 // the user this server answers to: the one who started it
	token      string
	listenAddr string // host:port actually bound; decides which Host headers are ours

	// Seams for the tests — the real ones shell out to nix and nh.
	metaLoader func(repo string) (map[string]FeatureMeta, error)
	jobCommand func(action, host string) []string

	catMu  sync.Mutex // one catalog load at a time
	fileMu sync.Mutex // one save or commit at a time: each is read, check, write
	mu     sync.Mutex // guards everything below

	meta     map[string]FeatureMeta // the catalog; nil until it has loaded
	catErr   string
	catTried bool
	sources  map[string]featureSource

	job    *job
	jobSeq int
	seen   time.Time
}

func newWebServer(repo string, hosts hostSet) (*webServer, error) {
	raw := make([]byte, 16)
	if _, err := rand.Read(raw); err != nil {
		return nil, err
	}
	hostname, _ := os.Hostname()
	return &webServer{
		repo:       repo,
		hosts:      hosts,
		hostname:   hostname,
		uid:        uint32(os.Getuid()),
		token:      hex.EncodeToString(raw),
		metaLoader: loadFeatureMeta,
		jobCommand: func(action, host string) []string {
			if action == "check" {
				return dryRunCommand(repo, host)
			}
			// No terminal here: nix-output-monitor would redraw its build
			// tree into the log, so ask nh for nix's plain output.
			return append(applyCommand(action, repo), "--no-nom")
		},
		seen: time.Now(),
	}, nil
}

func (s *webServer) handler() http.Handler {
	static, err := fs.Sub(webFiles, "web")
	if err != nil {
		panic(err) // the embedded tree always has web/
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", s.handleIndex)
	mux.Handle("GET /", http.FileServerFS(static))
	mux.HandleFunc("GET /api/ping", s.handlePing)
	mux.HandleFunc("GET /api/state", s.handleState)
	mux.HandleFunc("POST /api/toggle", s.handleToggle)
	mux.HandleFunc("POST /api/save", s.handleSave)
	mux.HandleFunc("POST /api/commit", s.handleCommit)
	mux.HandleFunc("GET /api/job", s.handleJob)
	mux.HandleFunc("POST /api/job", s.handleJobStart)
	mux.HandleFunc("POST /api/job/stop", s.handleJobStop)
	return s.guard(mux)
}

type peerKey struct{}

// connContext runs once per accepted connection and notes whose it is. A
// connection it cannot attribute carries no uid, and guard turns it away.
func (s *webServer) connContext(ctx context.Context, c net.Conn) context.Context {
	local, lok := c.LocalAddr().(*net.TCPAddr)
	remote, rok := c.RemoteAddr().(*net.TCPAddr)
	if !lok || !rok {
		return ctx
	}
	uid, err := peerUID(local.AddrPort(), remote.AddrPort())
	if err != nil {
		return ctx
	}
	return context.WithValue(ctx, peerKey{}, uid)
}

// guard is the whole security boundary; see the file comment.
func (s *webServer) guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Another account on this machine reaches loopback as easily as we
		// do. Nothing below would stop its curl: it sends the right Host, no
		// Origin, and can read the token off the page.
		if uid, ok := r.Context().Value(peerKey{}).(uint32); !ok || uid != s.uid {
			http.Error(w, "forbidden: this switchboard answers only to the user who started it", http.StatusForbidden)
			return
		}
		// A hostile page can point its own name at 127.0.0.1, but it cannot
		// make the browser send our Host.
		if !s.ourHost(r.Host) {
			http.Error(w, "forbidden: not this server's address", http.StatusForbidden)
			return
		}
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			if origin := r.Header.Get("Origin"); origin != "" {
				u, err := url.Parse(origin)
				if err != nil || u.Scheme != "http" || !s.ourHost(u.Host) {
					http.Error(w, "forbidden: cross-origin request", http.StatusForbidden)
					return
				}
			}
			if site := r.Header.Get("Sec-Fetch-Site"); site != "" && site != "same-origin" {
				http.Error(w, "forbidden: cross-site request", http.StatusForbidden)
				return
			}
		}
		if strings.HasPrefix(r.URL.Path, "/api/") && r.URL.Path != "/api/ping" {
			if subtle.ConstantTimeCompare([]byte(r.Header.Get(tokenHeader)), []byte(s.token)) != 1 {
				http.Error(w, "forbidden: missing or wrong token — reload the page", http.StatusForbidden)
				return
			}
			// Only our own page gets this far, so only it keeps the server
			// alive: any site can make a browser fetch /favicon.svg in a loop.
			s.mu.Lock()
			s.seen = time.Now()
			s.mu.Unlock()
		}

		h := w.Header()
		h.Set("Content-Security-Policy",
			"default-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Referrer-Policy", "no-referrer")
		// The page and the binary are one release: never serve one from cache
		// against the other.
		h.Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}

// ourHost reports whether a Host header (or an Origin's host) names this
// server: the bound address, or `localhost`, on the bound port.
func (s *webServer) ourHost(hostport string) bool {
	bound, port, err := net.SplitHostPort(s.listenAddr)
	if err != nil {
		return false
	}
	host, p, err := net.SplitHostPort(hostport)
	if err != nil || p != port {
		return false
	}
	return host == bound || host == "localhost"
}

// idleFor is how long our page has not asked for anything; a running job
// counts as activity, so a long build never gets the server shut down under it.
func (s *webServer) idleFor() time.Duration {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.job != nil && s.job.running {
		return 0
	}
	return time.Since(s.seen)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]any{"error": msg})
}

func readJSON(w http.ResponseWriter, r *http.Request, v any) bool {
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20)).Decode(v); err != nil {
		writeError(w, http.StatusBadRequest, "malformed request: "+err.Error())
		return false
	}
	return true
}

func (s *webServer) handleIndex(w http.ResponseWriter, r *http.Request) {
	page, err := webFiles.ReadFile("web/index.html")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(bytes.ReplaceAll(page, []byte(tokenPlaceholder), []byte(s.token)))
}

func (s *webServer) handlePing(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"app": "switchboard", "version": version, "repo": s.repo})
}

// ── state ───────────────────────────────────────────────────────────────────

type stateView struct {
	Version      string                 `json:"version"`
	Repo         string                 `json:"repo"`
	Hostname     string                 `json:"hostname"`
	Hosts        []hostView             `json:"hosts"`
	Catalog      map[string]featureView `json:"catalog"`
	CatalogError string                 `json:"catalogError,omitempty"`
}

type hostView struct {
	Name     string   `json:"name"`
	File     string   `json:"file"`
	Local    bool     `json:"local"` // this machine: test/switch apply here
	Rev      string   `json:"rev"`   // hash of the file; a save must quote it
	Features []string `json:"features"`
	// What the file holds that the last commit does not. Tracked is false
	// when git has no committed list to compare with (no repo, a new file) —
	// then the diff says nothing, and there is nothing to offer a commit for.
	Tracked     bool     `json:"tracked"`
	Uncommitted diffView `json:"uncommitted"`
	// What the loader would reject in the file as it is.
	Problems []string `json:"problems"`
	Error    string   `json:"error,omitempty"`
}

type diffView struct {
	Added   []string `json:"added"`
	Removed []string `json:"removed"`
}

// diffOf is FeatureDiff with lists that are never nil: the page reads them as
// JSON arrays.
func diffOf(before, after []string) diffView {
	added, removed := FeatureDiff(before, after)
	return diffView{Added: append([]string{}, added...), Removed: append([]string{}, removed...)}
}

type featureView struct {
	Kind              string   `json:"kind"`
	Requires          []string `json:"requires"`
	Conflicts         []string `json:"conflicts"`
	RuntimeUntestable bool     `json:"runtimeUntestable"`
	Provides          Provides `json:"provides"`
	Source            string   `json:"source,omitempty"`
	Notes             string   `json:"notes,omitempty"`
	Group             string   `json:"group,omitempty"`
}

// catalog returns the feature catalog, loading it on first use (or again on
// reload). A failed reload keeps the catalog that was there and reports why.
func (s *webServer) catalog(reload bool) (map[string]FeatureMeta, map[string]featureSource, string) {
	s.catMu.Lock()
	defer s.catMu.Unlock()
	s.mu.Lock()
	tried := s.catTried
	s.mu.Unlock()
	if !tried || reload {
		meta, err := s.metaLoader(s.repo)
		sources := indexSources(s.repo)
		s.mu.Lock()
		s.catTried = true
		if err != nil {
			s.catErr = err.Error()
		} else {
			s.meta, s.catErr, s.sources = meta, "", sources
		}
		s.mu.Unlock()
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.meta, s.sources, s.catErr
}

func (s *webServer) handleState(w http.ResponseWriter, r *http.Request) {
	meta, sources, catErr := s.catalog(r.URL.Query().Get("reload") == "1")
	view := stateView{
		Version:      version,
		Repo:         s.repo,
		Hostname:     s.hostname,
		Catalog:      map[string]featureView{},
		CatalogError: catErr,
	}
	for _, name := range s.hosts.order {
		view.Hosts = append(view.Hosts, s.hostView(name, meta))
	}
	for name, m := range meta {
		src := sources[name]
		view.Catalog[name] = featureView{
			Kind:              m.Kind,
			Requires:          append([]string{}, m.Requires...),
			Conflicts:         append([]string{}, m.Conflicts...),
			RuntimeUntestable: m.RuntimeUntestable,
			Provides:          m.Provides,
			Source:            src.File,
			Notes:             src.Notes,
			Group:             src.Group,
		}
	}
	writeJSON(w, http.StatusOK, view)
}

// hostView reads one host's file. meta is nil while the catalog is not loaded.
func (s *webServer) hostView(name string, meta map[string]FeatureMeta) hostView {
	v := hostView{
		Name:        name,
		File:        s.hosts.files[name],
		Local:       name == s.hostname,
		Features:    []string{},
		Uncommitted: diffOf(nil, nil),
		Problems:    []string{},
	}
	data, err := os.ReadFile(s.hosts.path(s.repo, name))
	if err != nil {
		v.Error = err.Error()
		return v
	}
	v.Rev = revOf(data)
	features, err := parseFeatures(data)
	if err != nil {
		v.Error = v.File + ": " + err.Error()
		return v
	}
	v.Features = append(v.Features, features...)
	if head, err := headFeatures(s.repo, v.File); err == nil {
		v.Tracked = true
		v.Uncommitted = diffOf(head, features)
	}
	if meta != nil {
		v.Problems = append(v.Problems, ValidateFeatures(meta, features)...)
	}
	return v
}

func revOf(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

// ── editing ─────────────────────────────────────────────────────────────────

// handleToggle flips one feature in the page's draft of a host's list. Nothing
// is stored: the draft comes in, the next draft goes out.
func (s *webServer) handleToggle(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Host     string   `json:"host"`
		Feature  string   `json:"feature"`
		Features []string `json:"features"`
	}
	if !readJSON(w, r, &req) {
		return
	}
	if !s.hosts.has(req.Host) {
		writeError(w, http.StatusNotFound, "no such host: "+req.Host)
		return
	}
	meta, _, catErr := s.catalog(false)
	if meta == nil {
		writeError(w, http.StatusServiceUnavailable, "the feature catalog is not loaded: "+catErr)
		return
	}
	res := Toggle(meta, req.Features, req.Feature)
	writeJSON(w, http.StatusOK, map[string]any{
		"features": append([]string{}, res.Features...),
		"changed":  res.Changed,
		"refused":  res.Refused,
		"message":  res.Message,
	})
}

func (s *webServer) handleSave(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Host     string   `json:"host"`
		Rev      string   `json:"rev"`
		Features []string `json:"features"`
	}
	if !readJSON(w, r, &req) {
		return
	}
	if !s.hosts.has(req.Host) {
		writeError(w, http.StatusNotFound, "no such host: "+req.Host)
		return
	}
	meta, _, catErr := s.catalog(false)
	if meta == nil {
		writeError(w, http.StatusServiceUnavailable, "the feature catalog is not loaded: "+catErr)
		return
	}
	s.fileMu.Lock()
	defer s.fileMu.Unlock()
	path := s.hosts.path(s.repo, req.Host)
	data, err := os.ReadFile(path)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	// The page edited a copy; if the file moved on meanwhile (the TUI, an
	// editor, git), saving would silently undo that.
	if revOf(data) != req.Rev {
		writeError(w, http.StatusConflict,
			s.hosts.files[req.Host]+" changed on disk since these edits began. Drop this host's unsaved edits to load the file as it is now, then redo the change.")
		return
	}
	current, err := parseFeatures(data)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	// Retained features keep the file's order, new ones go last — a toggle
	// off and on again must not reorder the file.
	next := ReconcileOrder(current, unique(req.Features))
	if problems := NewProblems(meta, current, next); len(problems) > 0 {
		writeJSON(w, http.StatusUnprocessableEntity, map[string]any{
			"error":    "the loader would reject this: " + strings.Join(problems, "; "),
			"problems": problems,
		})
		return
	}
	changed := !equalLists(next, current)
	if changed {
		if err := writeFeatures(path, next); err != nil {
			writeError(w, http.StatusInternalServerError, "saving: "+err.Error())
			return
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"changed": changed,
		"host":    s.hostView(req.Host, meta),
	})
}

func unique(list []string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(list))
	for _, f := range list {
		if !seen[f] {
			seen[f] = true
			out = append(out, f)
		}
	}
	return out
}

// handleCommit commits one host's feature list — that file only, whatever
// else is staged — under the subject the TUI uses.
func (s *webServer) handleCommit(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Host string `json:"host"`
	}
	if !readJSON(w, r, &req) {
		return
	}
	if !s.hosts.has(req.Host) {
		writeError(w, http.StatusNotFound, "no such host: "+req.Host)
		return
	}
	s.fileMu.Lock()
	defer s.fileMu.Unlock()
	file := s.hosts.files[req.Host]
	current, err := readFeatures(s.hosts.path(s.repo, req.Host))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	head, err := headFeatures(s.repo, file)
	if err != nil {
		writeError(w, http.StatusUnprocessableEntity, "git has no committed "+file+" to compare with")
		return
	}
	added, removed := FeatureDiff(head, current)
	if len(added) == 0 && len(removed) == 0 {
		writeError(w, http.StatusUnprocessableEntity, "nothing to commit for "+req.Host)
		return
	}
	message := commitMessage(req.Host, DiffString(added, removed))
	if out, err := gitCommit(s.repo, []string{file}, message); err != nil {
		writeError(w, http.StatusUnprocessableEntity, "git commit failed: "+tail(out, 400))
		return
	}
	meta, _, _ := s.catalog(false)
	writeJSON(w, http.StatusOK, map[string]any{
		"message": message,
		"host":    s.hostView(req.Host, meta),
	})
}

// ── jobs ────────────────────────────────────────────────────────────────────

// job is one command run on the page's behalf (nh os test/switch, a dry-run
// build). One at a time; the last one stays readable until the next starts.
type job struct {
	id        int
	action    string
	host      string
	command   string
	out       []byte // clean lines, capped at maxJobOutput
	truncated bool
	running   bool
	stopped   bool
	exit      int
	cancel    context.CancelFunc
	done      chan struct{} // closed when the command has ended
}

func (s *webServer) handleJobStart(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Action string `json:"action"`
		Host   string `json:"host"`
	}
	if !readJSON(w, r, &req) {
		return
	}
	if !s.hosts.has(req.Host) {
		writeError(w, http.StatusNotFound, "no such host: "+req.Host)
		return
	}
	switch req.Action {
	case "check":
	case "test", "switch":
		if req.Host != s.hostname {
			writeError(w, http.StatusUnprocessableEntity, fmt.Sprintf(
				"%s runs on this machine (%s) only — %s has to be applied from there", req.Action, s.hostname, req.Host))
			return
		}
	default:
		writeError(w, http.StatusBadRequest, "unknown action: "+req.Action)
		return
	}

	args := s.jobCommand(req.Action, req.Host)
	s.mu.Lock()
	if s.job != nil && s.job.running {
		busy := s.job.command
		s.mu.Unlock()
		writeError(w, http.StatusConflict, "still running: "+busy)
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	s.jobSeq++
	j := &job{
		id:      s.jobSeq,
		action:  req.Action,
		host:    req.Host,
		command: ShQuote(args),
		running: true,
		cancel:  cancel,
		done:    make(chan struct{}),
	}
	s.job = j
	s.mu.Unlock()

	go s.runJob(ctx, j, args)
	writeJSON(w, http.StatusAccepted, map[string]any{"job": s.jobView(j, 0)})
}

func (s *webServer) runJob(ctx context.Context, j *job, args []string) {
	defer close(j.done)
	defer j.cancel()
	lines := &lineWriter{emit: func(line string) { s.appendOutput(j, line, false) }}
	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	cmd.Dir = s.repo
	// One writer for both streams: os/exec then serialises the writes.
	cmd.Stdout, cmd.Stderr = lines, lines
	// Its own process group: Stop reaches nix's children too, and a Ctrl+C
	// in the server's terminal does not reach the job at all.
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGTERM) }
	cmd.WaitDelay = 10 * time.Second
	err := cmd.Run()
	lines.Flush()

	code := exitCode(err)
	s.mu.Lock()
	stopped := j.stopped
	s.mu.Unlock()
	switch {
	case stopped:
		s.appendOutput(j, "[switchboard] stopped", true)
	case code == -1 && err != nil:
		// Never started (binary missing), or died from a signal.
		s.appendOutput(j, "[switchboard] "+err.Error(), true)
	}
	s.mu.Lock()
	j.running, j.exit = false, code
	s.mu.Unlock()
}

// appendOutput adds a line of the command's output, up to the cap. final
// lines (how the job ended) are the server's own and always fit.
func (s *webServer) appendOutput(j *job, line string, final bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !final {
		if j.truncated {
			return
		}
		if len(j.out)+len(line)+1 > maxJobOutput {
			j.truncated = true
			line = "[switchboard] output truncated — the command is still running"
		}
	}
	j.out = append(append(j.out, line...), '\n')
}

func (s *webServer) jobView(j *job, offset int) map[string]any {
	s.mu.Lock()
	defer s.mu.Unlock()
	if offset < 0 || offset > len(j.out) {
		offset = 0
	}
	return map[string]any{
		"id":      j.id,
		"action":  j.action,
		"host":    j.host,
		"command": j.command,
		"running": j.running,
		"exit":    j.exit,
		"output":  string(j.out[offset:]),
		"next":    len(j.out),
	}
}

// handleJob returns the current (or last) job with its output from ?offset on
// — the page polls this while a job runs, naming the job (?id) it is following.
func (s *webServer) handleJob(w http.ResponseWriter, r *http.Request) {
	s.mu.Lock()
	j := s.job
	s.mu.Unlock()
	if j == nil {
		writeJSON(w, http.StatusOK, map[string]any{"job": nil})
		return
	}
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	// An offset only means something within the job it was counted in.
	if id := r.URL.Query().Get("id"); id != "" && id != strconv.Itoa(j.id) {
		offset = 0
	}
	writeJSON(w, http.StatusOK, map[string]any{"job": s.jobView(j, offset)})
}

func (s *webServer) handleJobStop(w http.ResponseWriter, r *http.Request) {
	if err := s.stopJob(); err != nil {
		writeError(w, http.StatusConflict, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// stopJob ends a running build check. An activation is never stopped: the
// signal goes to the job's process group, sudo is in it and relays it, and
// switch-to-configuration would die half-way through.
func (s *webServer) stopJob() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.job == nil || !s.job.running {
		return nil
	}
	if s.job.action != "check" {
		return errors.New("nh os " + s.job.action + " is not stopped half-way — let it finish")
	}
	s.job.stopped = true
	s.job.cancel()
	return nil
}

// applying returns the done channel of a running test/switch, nil otherwise.
func (s *webServer) applying() <-chan struct{} {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.job != nil && s.job.running && s.job.action != "check" {
		return s.job.done
	}
	return nil
}

// lineWriter turns a command's raw output into clean lines.
type lineWriter struct {
	pending []byte
	emit    func(line string)
}

func (w *lineWriter) Write(p []byte) (int, error) {
	w.pending = append(w.pending, p...)
	for {
		i := bytes.IndexByte(w.pending, '\n')
		if i < 0 {
			return len(p), nil
		}
		w.emit(cleanLine(string(w.pending[:i])))
		w.pending = w.pending[i+1:]
	}
}

// Flush emits a last line that never got its newline.
func (w *lineWriter) Flush() {
	if len(w.pending) > 0 {
		w.emit(cleanLine(string(w.pending)))
		w.pending = nil
	}
}

// CSI sequences (colours, cursor moves), OSC sequences (titles, hyperlinks),
// and the two-byte escapes.
var ansiEscape = regexp.MustCompile(`\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b[@-Z\\-_]`)

// cleanLine strips terminal escapes and, where a line was redrawn in place
// with carriage returns (a progress bar), keeps only what was drawn last.
func cleanLine(line string) string {
	line = strings.TrimRight(ansiEscape.ReplaceAllString(line, ""), "\r")
	if i := strings.LastIndexByte(line, '\r'); i >= 0 {
		line = line[i+1:]
	}
	return line
}
