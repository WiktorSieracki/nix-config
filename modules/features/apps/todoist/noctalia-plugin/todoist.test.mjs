// Unit tests for todoist.js — the pure logic behind the noctalia plugin.
// Run with `node --test` (the plugin derivation does this in its checkPhase).
//
// todoist.js is a QML JavaScript resource (`.pragma library`, no exports), so
// it is evaluated in a vm context instead of imported as a module.
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {test} from "node:test";
import vm from "node:vm";

const src = readFileSync(new URL("./todoist.js", import.meta.url), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const T = vm.createContext({});
vm.runInContext(src, T);

const task = (over = {}) => ({
  id: "1",
  content: "Task",
  description: "",
  priority: 1,
  due: null,
  projectId: "p-inbox",
  labels: [],
  url: "https://app.todoist.com/app/task/1",
  ...over,
});
const due = (date, extra = {}) => ({date, string: date, isRecurring: false, ...extra});
// vm contexts have their own Array prototype, so deepStrictEqual against a
// literal from this realm fails on prototype identity; JSON-roundtrip first.
const plain = (v) => JSON.parse(JSON.stringify(v));

test("parseTaskList reads td's paginated JSON", () => {
  const out = JSON.stringify({results: [task({id: "a"}), task({id: "b"})], nextCursor: null});
  assert.deepEqual(plain(T.parseTaskList(out).map((t) => t.id)), ["a", "b"]);
});

test("parseTaskList accepts a bare array and tolerates surrounding noise", () => {
  assert.equal(T.parseTaskList(JSON.stringify([task()])).length, 1);
  assert.equal(T.parseTaskList("\n" + JSON.stringify({results: []}) + "\n").length, 0);
});

test("parseTaskList normalizes missing optional fields", () => {
  const [t] = T.parseTaskList(JSON.stringify({results: [{id: "x", content: "Bare"}]}));
  assert.equal(t.priority, 1);
  assert.equal(t.due, null);
  assert.deepEqual(plain(t.labels), []);
  assert.equal(t.description, "");
});

test("parseTaskList skips a notice line printed before the JSON", () => {
  const out = "Update available: 5.5.0 → run `td update`\n" + JSON.stringify({results: [task()]});
  assert.equal(T.parseTaskList(out).length, 1);
});

test("parseTaskList throws on garbage so callers can surface the error", () => {
  assert.throws(() => T.parseTaskList("not json"));
});

test("parseProjects maps id to name", () => {
  const out = JSON.stringify({results: [{id: "p1", name: "Inbox"}, {id: "p2", name: "Work"}]});
  assert.deepEqual(plain(T.parseProjects(out)), {p1: "Inbox", p2: "Work"});
});

test("dueDay strips the time from floating and UTC datetimes", () => {
  assert.equal(T.dueDay(task({due: due("2026-10-16")})), "2026-10-16");
  assert.equal(T.dueDay(task({due: due("2026-10-16T14:30:00")})), "2026-10-16");
  assert.equal(T.dueDay(task()), "");
});

test("dueTime returns HH:MM only for timed tasks", () => {
  assert.equal(T.dueTime(task({due: due("2026-10-16T14:30:00")})), "14:30");
  assert.equal(T.dueTime(task({due: due("2026-10-16")})), "");
});

test("isOverdue compares calendar days, not instants", () => {
  const today = "2026-10-16";
  assert.equal(T.isOverdue(task({due: due("2026-10-15")}), today), true);
  assert.equal(T.isOverdue(task({due: due("2026-10-16T00:01:00")}), today), false);
  assert.equal(T.isOverdue(task({due: due("2026-10-17")}), today), false);
  assert.equal(T.isOverdue(task(), today), false);
});

test("addDays rolls over month boundaries", () => {
  assert.equal(T.addDays("2026-10-31", 1), "2026-11-01");
  assert.equal(T.addDays("2026-03-01", -1), "2026-02-28");
});

test("dueLabel uses relative words near today, a date otherwise", () => {
  const today = "2026-10-16"; // a Friday
  assert.equal(T.dueLabel(task({due: due("2026-10-16")}), today), "Today");
  assert.equal(T.dueLabel(task({due: due("2026-10-17")}), today), "Tomorrow");
  assert.equal(T.dueLabel(task({due: due("2026-10-15")}), today), "Yesterday");
  assert.equal(T.dueLabel(task({due: due("2026-10-20")}), today), "Tue");
  assert.equal(T.dueLabel(task({due: due("2026-11-30")}), today), "30 Nov");
  assert.equal(T.dueLabel(task({due: due("2027-01-05")}), today), "5 Jan 2027");
  assert.equal(T.dueLabel(task({due: due("2026-10-16T09:05:00")}), today), "Today 09:05");
  assert.equal(T.dueLabel(task(), today), "");
});

test("sortTasks: earlier day first, then timed before untimed, then priority", () => {
  const tasks = [
    task({id: "late", due: due("2026-10-17")}),
    task({id: "p4", due: due("2026-10-16"), priority: 1}),
    task({id: "p1", due: due("2026-10-16"), priority: 4}),
    task({id: "timed", due: due("2026-10-16T08:00:00"), priority: 1}),
    task({id: "nodate"}),
  ];
  assert.deepEqual(plain(T.sortTasks(tasks).map((t) => t.id)), ["timed", "p1", "p4", "late", "nodate"]);
});

test("buildRows(today) splits overdue from today with counted headers", () => {
  const today = "2026-10-16";
  const rows = T.buildRows("today", [
    task({id: "t", due: due("2026-10-16")}),
    task({id: "o", due: due("2026-10-14")}),
  ], today);
  assert.deepEqual(plain(rows.map((r) => (r.kind === "header" ? `# ${r.title} ${r.count}` : r.task.id))), [
    "# Overdue 1",
    "o",
    "# Today 1",
    "t",
  ]);
  assert.equal(rows[0].urgent, true);
  assert.equal(rows[2].urgent, false);
});

test("buildRows(today) omits empty sections and returns [] for nothing", () => {
  assert.deepEqual(plain(T.buildRows("today", [], "2026-10-16")), []);
  const rows = T.buildRows("today", [task({due: due("2026-10-16")})], "2026-10-16");
  assert.equal(rows[0].title, "Today");
});

test("buildRows(upcoming) groups per day", () => {
  const today = "2026-10-16";
  const rows = T.buildRows("upcoming", [
    task({id: "b", due: due("2026-10-18")}),
    task({id: "a", due: due("2026-10-17")}),
    task({id: "c", due: due("2026-10-18")}),
    task({id: "o", due: due("2026-10-01")}),
  ], today);
  assert.deepEqual(plain(rows.map((r) => (r.kind === "header" ? `# ${r.title}` : r.task.id))), [
    "# Overdue",
    "o",
    "# Tomorrow",
    "a",
    "# Sun 18 Oct",
    "b",
    "c",
  ]);
});

test("buildRows(inbox) keeps Todoist's order and has no headers", () => {
  const rows = T.buildRows("inbox", [task({id: "z"}), task({id: "a", due: due("2026-10-10")})], "2026-10-16");
  assert.deepEqual(plain(rows.map((r) => r.kind + ":" + r.task.id)), ["task:z", "task:a"]);
});

test("priorityColor follows Todoist's palette (API 4 == p1)", () => {
  assert.equal(T.priorityColor(4), "#d1453b");
  assert.equal(T.priorityColor(3), "#eb8909");
  assert.equal(T.priorityColor(2), "#246fe0");
  assert.equal(T.priorityColor(1), "");
});

test("plainText strips the markdown Todoist allows in titles", () => {
  assert.equal(T.plainText("Read [the docs](https://x.y) **now**"), "Read the docs now");
  assert.equal(T.plainText("`code` and __bold__ and *it*"), "code and bold and it");
  assert.equal(T.plainText("2 * 3 = 6"), "2 * 3 = 6");
});

test("quickAddArgs ends option parsing so a leading dash stays content", () => {
  assert.deepEqual(plain(T.quickAddArgs("  -5 kg by Friday ")), ["add", "--json", "--", "-5 kg by Friday"]);
  assert.equal(T.quickAddArgs("   "), null);
});

test("describeError flags a missing token as an auth problem", () => {
  const e = T.describeError(1, "No API token found. Set TODOIST_API_TOKEN or run `td auth login`.\n");
  assert.equal(e.needsAuth, true);
  const net = T.describeError(1, "Error: getaddrinfo ENOTFOUND api.todoist.com\n");
  assert.equal(net.needsAuth, false);
  assert.match(net.message, /ENOTFOUND/);
  assert.match(T.describeError(2, "").message, /exit code 2/);
});

test("describeError reads the JSON error td prints in --json mode", () => {
  const stderr = JSON.stringify({
    error: {code: "NO_TOKEN", message: "No API token found. Set TODOIST_API_TOKEN or run `td auth login`.", hints: []},
  });
  const e = T.describeError(1, stderr + "\n");
  assert.equal(e.needsAuth, true);
  assert.equal(e.message, "No API token found. Set TODOIST_API_TOKEN or run `td auth login`.");
  const other = T.describeError(1, JSON.stringify({error: {code: "TASK_NOT_FOUND", message: "Task id:9 not found."}}));
  assert.equal(other.needsAuth, false);
  assert.equal(other.message, "Task id:9 not found.");
});

test("countActive counts today+overdue minus tasks being completed", () => {
  const today = "2026-10-16";
  const tasks = [
    task({id: "a", due: due("2026-10-16")}),
    task({id: "b", due: due("2026-10-10")}),
    task({id: "c", due: due("2026-10-20")}),
  ];
  assert.deepEqual(plain(T.countActive([], tasks, {}, today)), {total: 2, overdue: 1});
  assert.deepEqual(plain(T.countActive([], tasks, {b: true}, today)), {total: 1, overdue: 0});
});

test("countActive counts every inbox task, dated or not", () => {
  const today = "2026-10-16";
  const inbox = [task({id: "i1"}), task({id: "i2", due: due("2026-10-30")})];
  assert.deepEqual(plain(T.countActive(inbox, [], {}, today)), {total: 2, overdue: 0});
  assert.deepEqual(plain(T.countActive(inbox, [], {i1: true}, today)), {total: 1, overdue: 0});
});

test("countActive counts an inbox task due today once", () => {
  const today = "2026-10-16";
  const shared = task({id: "s", due: due("2026-10-12")});
  const inbox = [shared, task({id: "i"})];
  const todayList = [shared, task({id: "t", due: due("2026-10-16"), projectId: "p-work"})];
  assert.deepEqual(plain(T.countActive(inbox, todayList, {}, today)), {total: 3, overdue: 1});
});
