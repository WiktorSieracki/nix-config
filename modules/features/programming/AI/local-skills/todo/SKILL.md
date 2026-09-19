---
name: todo
description: Add, list, complete or remove items on the user's personal todo list — the Todo List plugin in the noctalia bar. Use when the user says "dodaj todo", "zapisz to jako todo", "add a todo", "put that on my todo list", "remind me to X", "co mam na liście", "what's on my todo list", or "mark X as done"; also when they drop a task mid-conversation and want it kept for later. NOT for the agent's own in-session task tracking.
allowed-tools:
  - Bash
---

# Todo

The user's todo list lives in the **Todo List plugin of the noctalia bar**
(`plugin:todo`). It is driven over Quickshell IPC with the `noctalia-ipc` CLI.
State persists to `~/.config/noctalia/plugins/todo/settings.json`, but that file
is an output — never an input (see Gotchas).

## Commands

```bash
noctalia-ipc call plugin:todo addTodoDefault "text"     # medium priority, current page
noctalia-ipc call plugin:todo addTodo "text" high 0     # (text, priority, pageId)
noctalia-ipc call plugin:todo getTodos                  # JSON array of all todos
noctalia-ipc call plugin:todo getCount                  # {"total":N,"active":N,"completed":N}
noctalia-ipc call plugin:todo toggleTodo "<id>"         # flip completed
noctalia-ipc call plugin:todo removeTodo "<id>"
noctalia-ipc call plugin:todo setTodoText "<id>" "text"
noctalia-ipc call plugin:todo setTodoPriority "<id>" high
noctalia-ipc call plugin:todo setTodoDetails "<id>" "longer notes"
noctalia-ipc call plugin:todo clearCompleted
noctalia-ipc call plugin:todo getPages                  # [{"id":0,"name":"General"}]
noctalia-ipc show                                       # authoritative signature list
```

Priority is one of `high`, `medium`, `low`. `id` is the plugin's numeric id as a
string — get it from `getTodos`, never guess it.

## Gotchas

**`noctalia-ipc` exits 0 even when the call did nothing.** A typo'd target
("Target not found."), an invalid priority, or a nonexistent page all print
little or nothing and still return success. Exit codes are only meaningful when
noctalia itself isn't reachable (exit 255, "No running instances"). So:

> After every write, verify with `getCount` or `getTodos`. Never report a todo
> as saved on the strength of the exit code alone.

**The plugin README documents the wrong argument order.** It shows
`addTodo "text" 0 "medium"`. The real signature is
`addTodo(text, priority, pageId)` — priority *before* page. Wrong order is
silently rejected.

**Never hand-edit `~/.config/noctalia/plugins/todo/settings.json`.** While
noctalia runs it holds the list in memory and rewrites that file on every
change, so an external edit is clobbered at the next GUI action. IPC is the only
safe write path.

**If noctalia isn't running**, the call fails with exit 255. Say so plainly and
offer to hold the item; do not fall back to editing the JSON.

## Writing the item

- **One task per todo.** If the user drops a compound request ("ogarnij X i Y"),
  add two items rather than one long one.
- **Match the user's language.** They write their todos in Polish; keep the text
  in the language they used.
- **Short and actionable** — a noun phrase or an imperative, sized to be readable
  in a bar widget. Push any elaboration into `setTodoDetails`, not the title.
- **Don't editorialize.** Save what they asked for; don't add your own inferred
  follow-ups as extra items.

## Reporting back

Echo the exact text saved and the resulting active count, e.g.
`zapisane: "setup t3code na telefonie" (aktywne: 4)`. When listing, render
`getTodos` as a plain list grouped by page, with the id alongside each item so a
follow-up "usuń to drugie" can be resolved without another round trip.
