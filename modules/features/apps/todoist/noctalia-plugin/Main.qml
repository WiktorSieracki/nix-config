import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import "todoist.js" as Todoist

// State + I/O for the Todoist plugin. Every read and write goes through the
// official `td` CLI; Todoist itself is the only store, so whatever is ticked
// here shows up on the phone on its next sync. BarWidget and Panel only bind
// to the properties below and call the functions.
Item {
  id: root

  property var pluginApi: null

  // Store paths substituted at build time (see todoist.nix), so the plugin
  // never depends on noctalia's PATH.
  readonly property string tdBin: "@td@"
  readonly property string appBin: "@todoistApp@"

  // Tasks per view, as returned by `td`.
  property var todayTasks: []
  property var upcomingTasks: []
  property var inboxTasks: []
  property var projects: ({})
  // id -> true while a completion is in flight or waiting to settle; ticking
  // again within the settle window undoes it.
  property var completing: ({})
  // view -> true while a fetch for it runs
  property var loadingViews: ({})

  property string errorText: ""
  property bool needsAuth: false
  property bool authInProgress: false
  property date lastSync

  property string today: Todoist.localDate(new Date())
  // Bar count = Inbox + due today/overdue anywhere, each task once.
  readonly property var counts: Todoist.countActive(inboxTasks, todayTasks, completing, today)
  readonly property int activeCount: counts.total
  readonly property int overdueCount: counts.overdue
  readonly property int inboxCount: Todoist.countActive(inboxTasks, [], completing, today).total
  readonly property int todayCount: Todoist.countActive([], todayTasks, completing, today).total
  readonly property string view: pluginApi?.pluginSettings?.view || "inbox"

  function tasksFor(v) {
    return v === "inbox" ? inboxTasks : v === "upcoming" ? upcomingTasks : todayTasks;
  }

  function isLoading(v) {
    return loadingViews[v] === true;
  }

  // ── td runner ───────────────────────────────────────────────────────────

  Component {
    id: tdProcess

    Process {
      id: proc
      property var callback: null
      stdout: StdioCollector {}
      stderr: StdioCollector {}
      onExited: function (exitCode) {
        var out = String(proc.stdout.text || "");
        var err = String(proc.stderr.text || "");
        if (proc.callback)
          proc.callback(exitCode, out, err);
        proc.destroy();
      }
    }
  }

  function runTd(args, callback) {
    var p = tdProcess.createObject(root, {
                                     "command": [root.tdBin].concat(args),
                                     "callback": callback
                                   });
    p.running = true;
  }

  function setLoading(v, on) {
    var next = Object.assign({}, loadingViews);
    next[v] = on;
    loadingViews = next;
  }

  function handleError(exitCode, stderr) {
    var e = Todoist.describeError(exitCode, stderr);
    root.needsAuth = e.needsAuth;
    root.errorText = e.message;
    Logger.w("Todoist", "td failed:", e.message);
  }

  // ── reads ───────────────────────────────────────────────────────────────

  readonly property var viewArgs: ({
                                     "today": ["today", "--json", "--all"],
                                     "upcoming": ["upcoming", "7", "--json", "--all"],
                                     "inbox": ["inbox", "--json", "--all"]
                                   })

  function refresh(v) {
    v = v || "today";
    if (isLoading(v))
      return;
    setLoading(v, true);
    runTd(viewArgs[v], function (code, out, err) {
      setLoading(v, false);
      if (code !== 0) {
        handleError(code, err);
        return;
      }
      try {
        var tasks = Todoist.parseTaskList(out);
      } catch (e) {
        root.errorText = "Unexpected output from td: " + e;
        return;
      }
      root.today = Todoist.localDate(new Date());
      if (v === "today")
        root.todayTasks = tasks;
      else if (v === "upcoming")
        root.upcomingTasks = tasks;
      else
        root.inboxTasks = tasks;
      root.errorText = "";
      root.needsAuth = false;
      root.lastSync = new Date();
    });
  }

  function refreshProjects() {
    runTd(["project", "list", "--json", "--all"], function (code, out, err) {
      if (code !== 0)
        return; // the task fetches surface the same error
      try {
        root.projects = Todoist.parseProjects(out);
      } catch (e) {
        Logger.w("Todoist", "Could not parse projects:", e);
      }
    });
  }

  // The two views the bar count is built from.
  function refreshCounted() {
    refresh("inbox");
    refresh("today");
  }

  // Panel open / manual refresh: the counted views plus the visible one.
  function refreshAll() {
    refreshCounted();
    if (view === "upcoming")
      refresh(view);
    refreshProjects();
  }

  // ── writes ──────────────────────────────────────────────────────────────

  function setCompleting(id, on) {
    var next = Object.assign({}, completing);
    if (on)
      next[id] = true;
    else
      delete next[id];
    completing = next;
  }

  function toggleTask(id) {
    if (completing[id]) {
      // Undo inside the settle window.
      setCompleting(id, false);
      runTd(["task", "uncomplete", "id:" + id], function (code, out, err) {
        if (code !== 0)
          ToastService.showError("Todoist", Todoist.describeError(code, err).message);
        settleTimer.restart();
      });
      return;
    }
    setCompleting(id, true);
    runTd(["task", "complete", "id:" + id], function (code, out, err) {
      if (code !== 0) {
        setCompleting(id, false);
        ToastService.showError("Todoist", Todoist.describeError(code, err).message);
        return;
      }
      settleTimer.restart();
    });
  }

  // Ticked tasks stay visible (struck through) for a moment so a misclick can
  // be undone, then a refresh drops them — or moves a recurring one to its
  // next date.
  Timer {
    id: settleTimer
    interval: 2500
    onTriggered: {
      root.completing = {};
      root.refreshAll();
    }
  }

  function addTask(text, onDone) {
    var args = Todoist.quickAddArgs(text);
    if (!args)
      return;
    runTd(args, function (code, out, err) {
      if (code !== 0) {
        ToastService.showError("Todoist", Todoist.describeError(code, err).message);
        if (onDone)
          onDone(false);
        return;
      }
      var where = "";
      try {
        var created = JSON.parse(out.trim());
        where = root.projects[created.projectId] || "";
      } catch (e) {}
      ToastService.showNotice("Todoist", where ? "Added to " + where : "Task added");
      if (onDone)
        onDone(true);
      root.refreshAll();
    });
  }

  function login() {
    if (authInProgress)
      return;
    authInProgress = true;
    runTd(["auth", "login"], function (code, out, err) {
      root.authInProgress = false;
      if (code !== 0) {
        handleError(code, err);
        return;
      }
      root.refreshAll();
    });
  }

  function openApp() {
    Quickshell.execDetached([root.appBin]);
  }

  // ── background refresh (keeps the bar count current) ────────────────────

  Timer {
    interval: Math.max(15000, pluginApi?.pluginSettings?.refreshInterval || 60000)
    running: root.pluginApi !== null
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshCounted()
  }

  // ── IPC ─────────────────────────────────────────────────────────────────
  // noctalia-ipc call plugin:todoist refresh   — e.g. after `td add` elsewhere

  IpcHandler {
    target: "plugin:todoist"

    function togglePanel() {
      if (!root.pluginApi)
        return;
      root.pluginApi.withCurrentScreen(screen => {
                                         root.pluginApi.togglePanel(screen);
                                       });
    }

    function refresh() {
      root.refreshAll();
    }

    function getCount(): string {
      return JSON.stringify({
                              "total": root.activeCount,
                              "inbox": root.inboxCount,
                              "today": root.todayCount,
                              "overdue": root.overdueCount,
                              "error": root.errorText
                            });
    }

    function getTasks(): string {
      return JSON.stringify({
                              "inbox": root.inboxTasks,
                              "today": root.todayTasks
                            });
    }
  }
}
