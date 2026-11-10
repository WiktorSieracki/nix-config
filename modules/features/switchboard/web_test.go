package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

const (
	desktopFile = "modules/hosts/desktop-nixos/features.json"
	laptopFile  = "modules/hosts/laptop-nixos/features.json"
)

// webTest is a running web server over a throwaway git repository with two
// hosts, standing in for "this machine is desktopNixos". The catalog and the
// commands are stubbed: there is no nix or nh in the build sandbox.
type webTest struct {
	t    *testing.T
	s    *webServer
	ts   *httptest.Server
	repo string
}

func newWebTest(t *testing.T) *webTest {
	t.Helper()
	repo := newRepo(t)
	for name, content := range map[string]string{
		"flake.nix": "{}\n",
		desktopFile: string(MarshalSpec(spec([]string{"niri", "desktop", "sops"},
			map[string][]string{"wiktor": {"git"}}))),
		laptopFile: string(MarshalSpec(spec([]string{"sops"},
			map[string][]string{"wiktor": {"git"}}))),
	} {
		if err := os.MkdirAll(filepath.Dir(filepath.Join(repo, name)), 0o755); err != nil {
			t.Fatal(err)
		}
		write(t, repo, name, content)
	}
	git(t, repo, "add", "--", "flake.nix", desktopFile, laptopFile)
	git(t, repo, "commit", "-q", "-m", "hosts")

	hosts, err := discoverHosts(repo)
	if err != nil {
		t.Fatal(err)
	}
	s, err := newWebServer(repo, hosts)
	if err != nil {
		t.Fatal(err)
	}
	s.hostname = "desktopNixos"
	s.catalogLoader = func(string) (Catalog, error) { return rulesCat, nil }
	s.jobCommand = func(action, host string) []string {
		return []string{"sh", "-c", "echo " + action + " " + host}
	}
	ts := httptest.NewUnstartedServer(s.handler())
	ts.Config.ConnContext = s.connContext
	s.listenAddr = ts.Listener.Addr().String()
	ts.Start()
	t.Cleanup(ts.Close)
	return &webTest{t: t, s: s, ts: ts, repo: repo}
}

// do sends a request the way the page does — token included — after letting
// tweak change it, and returns the status and the decoded JSON body (nil when
// the body is not JSON).
func (w *webTest) do(method, path string, body any, tweak func(*http.Request)) (int, map[string]any) {
	w.t.Helper()
	var payload io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			w.t.Fatal(err)
		}
		payload = bytes.NewReader(data)
	}
	req, err := http.NewRequest(method, w.ts.URL+path, payload)
	if err != nil {
		w.t.Fatal(err)
	}
	req.Header.Set(tokenHeader, w.s.token)
	if tweak != nil {
		tweak(req)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		w.t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	var decoded map[string]any
	json.Unmarshal(raw, &decoded)
	return resp.StatusCode, decoded
}

func (w *webTest) get(path string) (int, map[string]any) {
	return w.do(http.MethodGet, path, nil, nil)
}

func (w *webTest) post(path string, body any) (int, map[string]any) {
	return w.do(http.MethodPost, path, body, nil)
}

// host returns one host's entry of /api/state.
func (w *webTest) host(name string) map[string]any {
	w.t.Helper()
	_, state := w.get("/api/state")
	for _, h := range state["hosts"].([]any) {
		if h.(map[string]any)["name"] == name {
			return h.(map[string]any)
		}
	}
	w.t.Fatalf("no host %s in state", name)
	return nil
}

func (w *webTest) fileSpec(file string) HostSpec {
	w.t.Helper()
	s, err := readSpec(filepath.Join(w.repo, filepath.FromSlash(file)))
	if err != nil {
		w.t.Fatal(err)
	}
	return s
}

// strs reads a JSON array of strings.
func strs(v any) []string {
	out := []string{}
	for _, x := range v.([]any) {
		out = append(out, x.(string))
	}
	return out
}

// ── the security boundary ───────────────────────────────────────────────────

func TestWebIndexCarriesTheToken(t *testing.T) {
	w := newWebTest(t)
	resp, err := http.Get(w.ts.URL + "/")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	page, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET / = %d", resp.StatusCode)
	}
	if !bytes.Contains(page, []byte(w.s.token)) {
		t.Error("the page must carry this run's token")
	}
	if bytes.Contains(page, []byte(tokenPlaceholder)) {
		t.Error("the token placeholder was served unreplaced")
	}
	if csp := resp.Header.Get("Content-Security-Policy"); !strings.Contains(csp, "default-src 'self'") {
		t.Errorf("Content-Security-Policy = %q, want default-src 'self'", csp)
	}
}

// Loopback is shared by every account on the machine. Another user's curl
// sends the right Host, no Origin, and could read the token off the page —
// it is turned away for whose connection it is, before any of that.
func TestWebAnswersOnlyToTheUserWhoStartedIt(t *testing.T) {
	w := newWebTest(t)
	w.s.uid++ // every connection now comes from "someone else"
	for _, path := range []string{"/", "/app.js", "/api/ping", "/api/state"} {
		if status, _ := w.get(path); status != http.StatusForbidden {
			t.Errorf("GET %s from another user = %d, want 403", path, status)
		}
	}
	if status, _ := w.post("/api/job", map[string]string{"action": "switch", "host": "desktopNixos"}); status != http.StatusForbidden {
		t.Errorf("POST /api/job from another user = %d, want 403", status)
	}
}

// DNS rebinding: a hostile page resolves its own name to 127.0.0.1 and reads
// us as "same origin" — but the browser then sends that name as Host.
func TestWebRefusesAForeignHostHeader(t *testing.T) {
	w := newWebTest(t)
	for _, path := range []string{"/", "/api/ping", "/api/state"} {
		status, _ := w.do(http.MethodGet, path, nil, func(r *http.Request) { r.Host = "evil.example:80" })
		if status != http.StatusForbidden {
			t.Errorf("GET %s with a foreign Host = %d, want 403", path, status)
		}
	}
}

func TestWebAPINeedsTheToken(t *testing.T) {
	w := newWebTest(t)
	status, _ := w.do(http.MethodGet, "/api/state", nil, func(r *http.Request) { r.Header.Del(tokenHeader) })
	if status != http.StatusForbidden {
		t.Errorf("GET /api/state without the token = %d, want 403", status)
	}
	status, _ = w.do(http.MethodPost, "/api/job", map[string]string{"action": "switch", "host": "desktopNixos"},
		func(r *http.Request) { r.Header.Set(tokenHeader, "guess") })
	if status != http.StatusForbidden {
		t.Errorf("POST /api/job with a wrong token = %d, want 403", status)
	}
	// ping is what a second `switchboard web` probes for — it has no token.
	if status, body := w.do(http.MethodGet, "/api/ping", nil, func(r *http.Request) { r.Header.Del(tokenHeader) }); status != http.StatusOK || body["app"] != "switchboard" {
		t.Errorf("GET /api/ping = %d %v, want 200 app=switchboard", status, body)
	}
}

func TestWebRefusesCrossOriginWrites(t *testing.T) {
	w := newWebTest(t)
	body := map[string]string{"action": "check", "host": "laptopNixos"}
	status, _ := w.do(http.MethodPost, "/api/job", body, func(r *http.Request) { r.Header.Set("Origin", "http://evil.example") })
	if status != http.StatusForbidden {
		t.Errorf("POST with a foreign Origin = %d, want 403", status)
	}
	status, _ = w.do(http.MethodPost, "/api/job", body, func(r *http.Request) { r.Header.Set("Sec-Fetch-Site", "cross-site") })
	if status != http.StatusForbidden {
		t.Errorf("POST marked cross-site = %d, want 403", status)
	}
	// The page's own writes carry its own origin.
	status, _ = w.do(http.MethodPost, "/api/job", body, func(r *http.Request) {
		r.Header.Set("Origin", w.ts.URL)
		r.Header.Set("Sec-Fetch-Site", "same-origin")
	})
	if status != http.StatusAccepted {
		t.Errorf("same-origin POST = %d, want 202", status)
	}
}

// Bound to a loopback address other than 127.0.0.1, that address is the one
// the Host header has to name.
func TestOurHostFollowsTheBoundAddress(t *testing.T) {
	s := &webServer{listenAddr: "127.0.0.2:7391"}
	for hostport, want := range map[string]bool{
		"127.0.0.2:7391": true,
		"localhost:7391": true,
		"127.0.0.1:7391": false,
		"127.0.0.2:8080": false,
		"evil.example":   false,
	} {
		if got := s.ourHost(hostport); got != want {
			t.Errorf("ourHost(%q) = %v, want %v", hostport, got, want)
		}
	}
	six := &webServer{listenAddr: "[::1]:7391"}
	if !six.ourHost("[::1]:7391") || six.ourHost("127.0.0.1:7391") {
		t.Error("bound to ::1, only [::1] and localhost are ours")
	}
}

// Any site can make a browser fetch /favicon.svg in a loop; that must not
// keep the server from its idle shutdown. Only our page's API calls count.
func TestWebIdleClockOnlyCountsOurPage(t *testing.T) {
	w := newWebTest(t)
	longAgo := func() {
		w.s.mu.Lock()
		w.s.seen = time.Now().Add(-time.Hour)
		w.s.mu.Unlock()
	}
	longAgo()
	for _, path := range []string{"/", "/favicon.svg", "/api/ping"} {
		w.do(http.MethodGet, path, nil, func(r *http.Request) { r.Header.Del(tokenHeader) })
	}
	w.do(http.MethodGet, "/api/state", nil, func(r *http.Request) { r.Header.Set(tokenHeader, "guess") })
	if idle := w.s.idleFor(); idle < 59*time.Minute {
		t.Errorf("idleFor = %v after requests without the token, want it untouched (~1h)", idle)
	}
	w.get("/api/state")
	if idle := w.s.idleFor(); idle > time.Minute {
		t.Errorf("idleFor = %v after the page's own request, want ~0", idle)
	}
}

// A second `switchboard web` asks the first what it serves, so it never opens
// the browser on another repo's instance.
func TestRunningInstanceReportsItsRepo(t *testing.T) {
	w := newWebTest(t)
	repo, ok := runningInstance(w.s.listenAddr)
	if !ok || repo != w.repo {
		t.Errorf("runningInstance = %q, %v; want %q", repo, ok, w.repo)
	}
	free, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	addr := free.Addr().String()
	free.Close()
	if _, ok := runningInstance(addr); ok {
		t.Error("nothing listens there — must not look like a switchboard")
	}
}

func TestRequireLoopback(t *testing.T) {
	for _, addr := range []string{"127.0.0.1:7391", "localhost:0", "[::1]:7391"} {
		if err := requireLoopback(addr); err != nil {
			t.Errorf("requireLoopback(%q) = %v, want ok", addr, err)
		}
	}
	for _, addr := range []string{"0.0.0.0:7391", ":7391", "192.168.1.10:7391", "example.com:80", "nonsense"} {
		if err := requireLoopback(addr); err == nil {
			t.Errorf("requireLoopback(%q) = ok, want a refusal", addr)
		}
	}
}

// ── state ───────────────────────────────────────────────────────────────────

func TestWebState(t *testing.T) {
	w := newWebTest(t)
	status, state := w.get("/api/state")
	if status != http.StatusOK {
		t.Fatalf("GET /api/state = %d", status)
	}
	hosts := state["hosts"].([]any)
	if len(hosts) != 2 {
		t.Fatalf("hosts = %d, want 2", len(hosts))
	}
	desktop := w.host("desktopNixos")
	if desktop["local"] != true || w.host("laptopNixos")["local"] != false {
		t.Error("only desktopNixos is this machine")
	}
	if got := strings.Join(strs(desktop["sections"]), " "); got != "system wiktor" {
		t.Errorf("sections = %q", got)
	}
	if got := strings.Join(strs(desktop["spec"].(map[string]any)["system"]), " "); got != "niri desktop sops" {
		t.Errorf("system = %q", got)
	}
	if n := len(desktop["uncommitted"].([]any)); n != 0 {
		t.Errorf("a freshly committed file reports %d uncommitted sections", n)
	}
	features := state["features"].(map[string]any)
	if features["git"].(map[string]any)["hm"] != true || features["niri"].(map[string]any)["hm"] != false {
		t.Error("hm must mark exactly the features with a home-manager part")
	}
	if got := strs(features["vscode"].(map[string]any)["requires"]); len(got) != 1 || got[0] != "desktop" {
		t.Errorf("vscode requires = %v", got)
	}
}

// A catalog that cannot be evaluated must not take the host lists down with it.
func TestWebStateSurvivesACatalogFailure(t *testing.T) {
	w := newWebTest(t)
	w.s.catalogLoader = func(string) (Catalog, error) { return Catalog{}, os.ErrDeadlineExceeded }
	status, state := w.get("/api/state")
	if status != http.StatusOK || state["catalogError"] == nil {
		t.Fatalf("GET /api/state = %d, catalogError = %v", status, state["catalogError"])
	}
	if len(state["hosts"].([]any)) != 2 {
		t.Error("the hosts must still be listed")
	}
	if status, _ := w.post("/api/toggle", map[string]any{
		"host": "desktopNixos", "section": "system", "feature": "tailscale",
		"spec": w.fileSpec(desktopFile),
	}); status != http.StatusServiceUnavailable {
		t.Errorf("toggle without a catalog = %d, want 503", status)
	}
}

// ── editing ─────────────────────────────────────────────────────────────────

func TestWebToggle(t *testing.T) {
	w := newWebTest(t)
	draft := w.fileSpec(laptopFile)

	status, res := w.post("/api/toggle", map[string]any{
		"host": "laptopNixos", "section": "wiktor", "feature": "vscode", "spec": draft,
	})
	if status != http.StatusOK || res["changed"] != true {
		t.Fatalf("toggle = %d %v", status, res)
	}
	got := strings.Join(strs(res["spec"].(map[string]any)["users"].(map[string]any)["wiktor"]), " ")
	if got != "git vscode desktop niri" {
		t.Errorf("wiktor = %q, want the feature plus its pulled requires", got)
	}
	if res["message"] != "Also enabled (required by vscode): desktop, niri" {
		t.Errorf("message = %q", res["message"])
	}

	_, res = w.post("/api/toggle", map[string]any{
		"host": "laptopNixos", "section": "system", "feature": "sops", "spec": draft,
	})
	if res["refused"] != true || res["changed"] != false {
		t.Errorf("disabling sops (required by wiktor's git) must be refused: %v", res)
	}
	// The draft never touched the disk.
	if !SpecEqual(w.fileSpec(laptopFile), draft) {
		t.Error("toggle must not write the file")
	}
}

func TestWebSaveWritesTheReconciledFile(t *testing.T) {
	w := newWebTest(t)
	// The page hands the lists back in its own order: retained features must
	// keep the file's order, new ones go last.
	draft := spec([]string{"sops", "tailscale", "desktop", "niri"},
		map[string][]string{"wiktor": {"git", "vscode"}})
	status, res := w.post("/api/save", map[string]any{
		"host": "desktopNixos", "rev": w.host("desktopNixos")["rev"], "spec": draft,
	})
	if status != http.StatusOK || res["changed"] != true {
		t.Fatalf("save = %d %v", status, res)
	}
	want := spec([]string{"niri", "desktop", "sops", "tailscale"},
		map[string][]string{"wiktor": {"git", "vscode"}})
	if got := w.fileSpec(desktopFile); !SpecEqual(got, want) {
		t.Errorf("file = %+v, want %+v", got, want)
	}
	data, _ := os.ReadFile(filepath.Join(w.repo, desktopFile))
	if !bytes.Equal(data, MarshalSpec(want)) {
		t.Errorf("file is not in the canonical shape:\n%s", data)
	}

	// The saved change is now what git has not seen.
	host := res["host"].(map[string]any)
	if host["rev"] == "" || host["rev"] == nil {
		t.Error("save must hand back the new rev")
	}
	diff, _ := json.Marshal(host["uncommitted"])
	if want := `[{"added":["tailscale"],"removed":[],"section":"system"},{"added":["vscode"],"removed":[],"section":"wiktor"}]`; string(diff) != want {
		t.Errorf("uncommitted = %s, want %s", diff, want)
	}
}

func TestWebSaveRefusesAStaleRev(t *testing.T) {
	w := newWebTest(t)
	rev := w.host("desktopNixos")["rev"]
	// Somebody else (the TUI, an editor) rewrites the file under the page.
	changed := spec([]string{"niri", "desktop", "sops", "tailscale"}, map[string][]string{"wiktor": {"git"}})
	write(t, w.repo, desktopFile, string(MarshalSpec(changed)))

	status, res := w.post("/api/save", map[string]any{
		"host": "desktopNixos", "rev": rev,
		"spec": spec([]string{"niri", "desktop", "sops"}, map[string][]string{"wiktor": {"git", "vscode"}}),
	})
	if status != http.StatusConflict {
		t.Fatalf("save over a changed file = %d %v, want 409", status, res)
	}
	if !SpecEqual(w.fileSpec(desktopFile), changed) {
		t.Error("a refused save must leave the other writer's file alone")
	}
}

func TestWebSaveRefusesWhatTheLoaderWouldReject(t *testing.T) {
	w := newWebTest(t)
	before := w.fileSpec(desktopFile)
	cases := map[string]HostSpec{
		"requires unmet":          spec([]string{"niri", "desktop"}, map[string][]string{"wiktor": {"git"}}),
		"home-manager in system":  spec([]string{"niri", "desktop", "sops", "git"}, map[string][]string{"wiktor": {"git"}}),
		"not a feature":           spec([]string{"niri", "desktop", "sops", "typo"}, map[string][]string{"wiktor": {"git"}}),
		"conflict in one account": spec([]string{"niri", "desktop", "sops"}, map[string][]string{"wiktor": {"git", "pstack", "other-skills"}}),
	}
	for name, draft := range cases {
		status, res := w.post("/api/save", map[string]any{
			"host": "desktopNixos", "rev": w.host("desktopNixos")["rev"], "spec": draft,
		})
		if status != http.StatusUnprocessableEntity {
			t.Errorf("%s: save = %d %v, want 422", name, status, res)
		}
		if !SpecEqual(w.fileSpec(desktopFile), before) {
			t.Fatalf("%s: a refused save wrote the file", name)
		}
	}
}

func TestWebSaveRefusesAccountChanges(t *testing.T) {
	w := newWebTest(t)
	status, _ := w.post("/api/save", map[string]any{
		"host": "desktopNixos", "rev": w.host("desktopNixos")["rev"],
		"spec": spec([]string{"niri", "desktop", "sops"}, map[string][]string{"wiktor": {"git"}, "intruder": {}}),
	})
	if status != http.StatusUnprocessableEntity {
		t.Errorf("save that adds an account = %d, want 422", status)
	}
}

func TestWebCommit(t *testing.T) {
	w := newWebTest(t)
	if status, _ := w.post("/api/commit", map[string]string{"host": "desktopNixos"}); status != http.StatusUnprocessableEntity {
		t.Errorf("commit with nothing changed = %d, want 422", status)
	}

	w.post("/api/save", map[string]any{
		"host": "desktopNixos", "rev": w.host("desktopNixos")["rev"],
		"spec": spec([]string{"niri", "desktop", "sops", "tailscale"}, map[string][]string{"wiktor": {"git"}}),
	})
	// Something the user staged for a commit of their own must stay out.
	write(t, w.repo, "other.nix", "other v2\n")
	git(t, w.repo, "add", "--", "other.nix")

	status, res := w.post("/api/commit", map[string]string{"host": "desktopNixos"})
	if status != http.StatusOK {
		t.Fatalf("commit = %d %v", status, res)
	}
	if got, want := git(t, w.repo, "log", "-1", "--format=%s"), "switchboard: desktopNixos system: +tailscale"; got != want {
		t.Errorf("subject = %q, want %q", got, want)
	}
	if got := git(t, w.repo, "show", "--name-only", "--format=", "HEAD"); got != desktopFile {
		t.Errorf("committed files = %q, want only %s", got, desktopFile)
	}
	if n := len(res["host"].(map[string]any)["uncommitted"].([]any)); n != 0 {
		t.Errorf("after the commit %d sections still count as uncommitted", n)
	}
}

// ── jobs ────────────────────────────────────────────────────────────────────

// waitJob polls like the page does until the job is over.
func (w *webTest) waitJob() map[string]any {
	w.t.Helper()
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		_, res := w.get("/api/job")
		if job := res["job"].(map[string]any); job["running"] == false {
			return job
		}
		time.Sleep(10 * time.Millisecond)
	}
	w.t.Fatal("the job never finished")
	return nil
}

func TestWebJobStreamsOutputAndExitCode(t *testing.T) {
	w := newWebTest(t)
	if _, res := w.get("/api/job"); res["job"] != nil {
		t.Errorf("job before any ran = %v, want null", res["job"])
	}
	w.s.jobCommand = func(action, host string) []string {
		return []string{"sh", "-c", `printf 'building\n\033[32mgreen\033[0m\n'; echo oops >&2; exit 3`}
	}
	status, res := w.post("/api/job", map[string]string{"action": "switch", "host": "desktopNixos"})
	if status != http.StatusAccepted {
		t.Fatalf("start = %d %v", status, res)
	}
	job := w.waitJob()
	if job["exit"] != float64(3) {
		t.Errorf("exit = %v, want 3", job["exit"])
	}
	out := job["output"].(string)
	for _, line := range []string{"building\n", "green\n", "oops\n"} {
		if !strings.Contains(out, line) {
			t.Errorf("output %q lacks %q", out, line)
		}
	}
	if strings.Contains(out, "\033") {
		t.Errorf("output still has terminal escapes: %q", out)
	}
	// The page asks only for what it has not seen yet.
	_, res = w.get("/api/job?offset=" + strconv.Itoa(int(job["next"].(float64))))
	if rest := res["job"].(map[string]any)["output"]; rest != "" {
		t.Errorf("output past the end = %q, want empty", rest)
	}
}

func TestWebJobOneAtATime(t *testing.T) {
	w := newWebTest(t)
	w.s.jobCommand = func(action, host string) []string { return []string{"sleep", "30"} }
	if status, _ := w.post("/api/job", map[string]string{"action": "check", "host": "laptopNixos"}); status != http.StatusAccepted {
		t.Fatalf("start = %d", status)
	}
	if status, _ := w.post("/api/job", map[string]string{"action": "check", "host": "desktopNixos"}); status != http.StatusConflict {
		t.Errorf("second job while one runs = %d, want 409", status)
	}
	// A running job is activity: the idle shutdown must not fire under it.
	if idle := w.s.idleFor(); idle != 0 {
		t.Errorf("idleFor during a job = %v, want 0", idle)
	}
	if status, _ := w.post("/api/job/stop", nil); status != http.StatusOK {
		t.Fatalf("stop = %d", status)
	}
	job := w.waitJob()
	if !strings.Contains(job["output"].(string), "[switchboard] stopped") {
		t.Errorf("output = %q, want the stop to be noted", job["output"])
	}
	if job["exit"] == float64(0) {
		t.Error("a stopped job must not report success")
	}
}

// SIGTERM to the job's process group reaches sudo, which relays it: stopping
// `nh os switch` could kill switch-to-configuration half-way. Only a build
// check may be stopped.
func TestWebActivationIsNotStoppedHalfWay(t *testing.T) {
	w := newWebTest(t)
	w.s.jobCommand = func(action, host string) []string {
		return []string{"sh", "-c", "sleep 0.3; echo activated"}
	}
	if status, _ := w.post("/api/job", map[string]string{"action": "switch", "host": "desktopNixos"}); status != http.StatusAccepted {
		t.Fatalf("start = %d", status)
	}
	if w.s.applying() == nil {
		t.Error("a running switch must count as applying (the shutdown waits on it)")
	}
	if status, res := w.post("/api/job/stop", nil); status != http.StatusConflict {
		t.Errorf("stop of a running switch = %d %v, want 409", status, res)
	}
	job := w.waitJob()
	if job["exit"] != float64(0) || !strings.Contains(job["output"].(string), "activated") {
		t.Errorf("the switch did not run to its end: %v", job)
	}
	if w.s.applying() != nil {
		t.Error("nothing is applying once the job is over")
	}
}

// How a job ended is the server's own line and must survive the output cap.
func TestWebJobOutputCapKeepsTheLastWord(t *testing.T) {
	w := newWebTest(t)
	j := &job{}
	w.s.appendOutput(j, strings.Repeat("x", maxJobOutput), false)
	w.s.appendOutput(j, "more output", false)
	w.s.appendOutput(j, "[switchboard] stopped", true)
	out := string(j.out)
	if strings.Contains(out, "more output") {
		t.Error("output past the cap must be dropped")
	}
	if !strings.Contains(out, "output truncated") || !strings.HasSuffix(out, "[switchboard] stopped\n") {
		t.Errorf("want the truncation notice and then the final line, got …%q", out[len(out)-120:])
	}
}

// test/switch activate the machine the server runs on — never offer them for
// another host's list.
func TestWebJobAppliesOnThisMachineOnly(t *testing.T) {
	w := newWebTest(t)
	for _, action := range []string{"test", "switch"} {
		if status, _ := w.post("/api/job", map[string]string{"action": action, "host": "laptopNixos"}); status != http.StatusUnprocessableEntity {
			t.Errorf("%s for another host = %d, want 422", action, status)
		}
	}
	if status, _ := w.post("/api/job", map[string]string{"action": "rm -rf", "host": "desktopNixos"}); status != http.StatusBadRequest {
		t.Errorf("unknown action = %d, want 400", status)
	}
	if status, _ := w.post("/api/job", map[string]string{"action": "check", "host": "nope"}); status != http.StatusNotFound {
		t.Errorf("unknown host = %d, want 404", status)
	}
}

// The real commands, not the stubs: this is what the buttons run.
func TestDefaultJobCommands(t *testing.T) {
	s, err := newWebServer("/repo", hostSet{})
	if err != nil {
		t.Fatal(err)
	}
	cases := map[string]string{
		"test":   "nh os test /repo --no-nom",
		"switch": "nh os switch /repo --no-nom",
		"check":  "nix build /repo#nixosConfigurations.laptopNixos.config.system.build.toplevel --dry-run",
	}
	for action, want := range cases {
		if got := strings.Join(s.jobCommand(action, "laptopNixos"), " "); got != want {
			t.Errorf("%s runs %q, want %q", action, got, want)
		}
	}
}

func TestCleanLine(t *testing.T) {
	cases := map[string]string{
		"plain":                    "plain",
		"\033[1;32mok\033[0m done": "ok done",
		"windows\r":                "windows",
		"10%\r50%\r100%":           "100%",
		"\033]8;;http://x\033\\link\033]8;;\033\\": "link",
		"\033[2K\033[1Gredrawn":                    "redrawn",
	}
	for in, want := range cases {
		if got := cleanLine(in); got != want {
			t.Errorf("cleanLine(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestLineWriterSplitsOnNewlinesAcrossWrites(t *testing.T) {
	var got []string
	lw := &lineWriter{emit: func(l string) { got = append(got, l) }}
	lw.Write([]byte("one\ntw"))
	lw.Write([]byte("o\nthree"))
	lw.Flush()
	if strings.Join(got, "|") != "one|two|three" {
		t.Errorf("lines = %q", got)
	}
}
