.pragma library

// Pure logic for the Todoist noctalia plugin: parse `td` JSON output and shape
// it for the panel. No QML/Quickshell imports here, so todoist.test.mjs can run
// it under plain node. Keep top-level names as `function`/`var` declarations —
// the test harness reads them off a vm context, where `const`/`let` would hide.

var WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Todoist API priorities run backwards: 4 is p1 (urgent), 1 is p4 (none).
var PRIORITY_COLORS = {4: "#d1453b", 3: "#eb8909", 2: "#246fe0"};

// ── parsing ────────────────────────────────────────────────────────────────

// `td … --json` prints {results, nextCursor}; accept a bare array as well.
// Parsing starts at the first line that opens JSON, so a notice td prints
// ahead of it can't break the panel.
function parseResults(stdout) {
  var text = String(stdout);
  var start = text.search(/^[\[{]/m);
  var data = JSON.parse(start > 0 ? text.slice(start) : text.trim());
  return Array.isArray(data) ? data : (data && data.results) || [];
}

function normalizeTask(t) {
  return {
    id: String(t.id),
    content: t.content || "",
    description: t.description || "",
    priority: typeof t.priority === "number" ? t.priority : 1,
    due: t.due || null,
    projectId: t.projectId || "",
    labels: t.labels || [],
    url: t.url || "",
  };
}

function parseTaskList(stdout) {
  return parseResults(stdout).map(normalizeTask);
}

function parseProjects(stdout) {
  var byId = {};
  parseResults(stdout).forEach(function (p) {
    byId[String(p.id)] = p.name;
  });
  return byId;
}

// ── dates ──────────────────────────────────────────────────────────────────
// Due dates are "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM:SS[Z]". All comparisons are
// on the calendar day string; day arithmetic goes through UTC so the host's
// time zone can't shift a date across midnight.

function pad(n) {
  return (n < 10 ? "0" : "") + n;
}

function localDate(d) {
  return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
}

function parseDay(day) {
  var p = day.split("-").map(Number);
  return new Date(Date.UTC(p[0], p[1] - 1, p[2]));
}

function addDays(day, n) {
  var d = parseDay(day);
  d.setUTCDate(d.getUTCDate() + n);
  return d.getUTCFullYear() + "-" + pad(d.getUTCMonth() + 1) + "-" + pad(d.getUTCDate());
}

function dueDay(task) {
  return task.due && task.due.date ? String(task.due.date).split("T")[0] : "";
}

function dueTime(task) {
  var date = task.due && task.due.date ? String(task.due.date) : "";
  var m = date.match(/T(\d\d):(\d\d)/);
  return m ? m[1] + ":" + m[2] : "";
}

function isOverdue(task, today) {
  var day = dueDay(task);
  return day !== "" && day < today;
}

function shortDate(day, today) {
  var d = parseDay(day);
  var s = d.getUTCDate() + " " + MONTHS[d.getUTCMonth()];
  return day.slice(0, 4) === today.slice(0, 4) ? s : s + " " + d.getUTCFullYear();
}

function relativeDay(day, today) {
  if (day === today)
    return "Today";
  if (day === addDays(today, 1))
    return "Tomorrow";
  if (day === addDays(today, -1))
    return "Yesterday";
  return "";
}

// Compact label for a task row: "Today", "Tue", "30 Nov", plus "HH:MM".
function dueLabel(task, today) {
  var day = dueDay(task);
  if (!day)
    return "";
  var label = relativeDay(day, today);
  if (!label)
    label = day > today && day <= addDays(today, 6) ? WEEKDAYS[parseDay(day).getUTCDay()] : shortDate(day, today);
  var time = dueTime(task);
  return time ? label + " " + time : label;
}

// Section header for the Upcoming view: "Tomorrow", "Sun 18 Oct".
function dayHeader(day, today) {
  return relativeDay(day, today) || WEEKDAYS[parseDay(day).getUTCDay()] + " " + shortDate(day, today);
}

// ── shaping ────────────────────────────────────────────────────────────────

// Earlier day first; within a day timed tasks first (by time), then by
// priority; undated last. Ties keep Todoist's own order.
function sortTasks(tasks) {
  return tasks.map(function (t, i) {
    return {t: t, i: i};
  }).sort(function (a, b) {
    var da = dueDay(a.t) || "9999-99-99";
    var db = dueDay(b.t) || "9999-99-99";
    if (da !== db)
      return da < db ? -1 : 1;
    var ta = dueTime(a.t);
    var tb = dueTime(b.t);
    if (ta !== tb)
      return !ta ? 1 : !tb ? -1 : ta < tb ? -1 : 1;
    if (a.t.priority !== b.t.priority)
      return b.t.priority - a.t.priority;
    return a.i - b.i;
  }).map(function (x) {
    return x.t;
  });
}

function header(title, count, urgent) {
  return {kind: "header", key: "h:" + title, title: title, count: count, urgent: urgent};
}

function taskRow(task) {
  return {kind: "task", key: task.id, task: task};
}

// Flatten a view into ListView rows: headers interleaved with tasks.
//   today    — Overdue / Today
//   upcoming — Overdue, then one group per day
//   inbox    — Todoist's order, no headers
function buildRows(view, tasks, today) {
  if (view === "inbox")
    return tasks.map(taskRow);

  var sorted = sortTasks(tasks);
  var groups = [];
  var byTitle = {};
  sorted.forEach(function (t) {
    var title;
    if (isOverdue(t, today))
      title = "Overdue";
    else if (view === "today")
      title = "Today";
    else
      title = dayHeader(dueDay(t), today);
    if (!byTitle[title]) {
      byTitle[title] = {title: title, tasks: []};
      groups.push(byTitle[title]);
    }
    byTitle[title].tasks.push(t);
  });

  var rows = [];
  groups.forEach(function (g) {
    rows.push(header(g.title, g.tasks.length, g.title === "Overdue"));
    g.tasks.forEach(function (t) {
      rows.push(taskRow(t));
    });
  });
  return rows;
}

// Bar count: everything in the Inbox (dated or not) plus whatever is due today
// or overdue elsewhere — each task once, tasks mid-completion excluded.
function countActive(inboxTasks, todayTasks, completing, today) {
  var seen = {};
  var total = 0;
  var overdue = 0;
  function add(t) {
    if (seen[t.id] || completing[t.id])
      return;
    seen[t.id] = true;
    total++;
    if (isOverdue(t, today))
      overdue++;
  }
  inboxTasks.forEach(add);
  todayTasks.forEach(function (t) {
    var day = dueDay(t);
    if (day && day <= today)
      add(t);
  });
  return {total: total, overdue: overdue};
}

function priorityColor(priority) {
  return PRIORITY_COLORS[priority] || "";
}

// Titles may carry Todoist markdown; the panel renders plain text.
function plainText(content) {
  return String(content)
    .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
    .replace(/\*\*(.+?)\*\*/g, "$1")
    .replace(/__(.+?)__/g, "$1")
    .replace(/`([^`]*)`/g, "$1")
    .replace(/\*(\S(?:.*?\S)?)\*/g, "$1");
}

// ── td invocation ──────────────────────────────────────────────────────────

// `--` stops option parsing, so content like "-5 kg" isn't read as a flag.
function quickAddArgs(text) {
  var trimmed = String(text).trim();
  return trimmed ? ["add", "--json", "--", trimmed] : null;
}

// In --json mode td reports failures as {"error":{"code","message"}} on
// stderr; plain-text stderr is handled too.
function describeError(exitCode, stderr) {
  var text = String(stderr || "").trim();
  var code = "";
  try {
    var err = JSON.parse(text).error;
    if (err && err.message) {
      text = err.message;
      code = err.code || "";
    }
  } catch (e) {}
  var needsAuth = code === "NO_TOKEN" || /no api token|auth login|\b401\b|unauthori[sz]ed|invalid token/i.test(text);
  var first = text.split("\n").filter(function (l) {
    return l.trim() !== "";
  })[0] || "";
  var message = first ? first.slice(0, 200) : "td failed (exit code " + exitCode + ")";
  return {needsAuth: needsAuth, message: message};
}
