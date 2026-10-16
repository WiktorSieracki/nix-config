---
name: todo
description: Add, list, complete or remove items on the user's personal todo list — their Todoist account, driven by the official `td` CLI and shown in the noctalia bar. Use when the user says "dodaj todo", "zapisz to jako todo", "add a todo", "put that on my todo list", "remind me to X", "co mam na liście", "what's on my todo list", or "mark X as done"; also when they drop a task mid-conversation and want it kept for later. NOT for the agent's own in-session task tracking.
allowed-tools:
  - Bash
---

# Todo

The user's todo list is **Todoist**. There is no local list: the noctalia bar
widget (`plugin:todoist`) and the phone app both read the same account, so
anything written with `td` shows up everywhere on the next sync.

## Commands

```bash
td add --json -- "Kupić mleko jutro p2 #Zakupy"  # natural-language quick add
td today --json                                  # due today + overdue
td upcoming 7 --json                             # next 7 days (and overdue)
td inbox --json
td task list --project "Praca" --json
td task view id:<id> --json
td task complete id:<id>
td task uncomplete id:<id>
td task update id:<id> --content "…" --due "friday" --priority p2
td task delete id:<id> --yes                     # destructive — confirm with the user first
```

Quick-add syntax inside the text: a date in natural language ("tomorrow",
"mon 9:00", "every friday"), `p1`–`p4` for priority (p1 is the most urgent),
`#Project`, `@label`. Without a project it lands in the Inbox.

Then nudge the bar so it doesn't wait for its 60-second poll:

```bash
WAYLAND_DISPLAY=wayland-1 noctalia-ipc call plugin:todoist refresh
```

That nudge is cosmetic: if it fails, say nothing about it.

## Gotchas

**Always pass `--` before the text.** `td add` parses options, so a task that
starts with a dash ("-5 kg") would otherwise be read as a flag.

**Refer to tasks by `id:<id>`, never by name.** Name refs match fuzzily and fail
with `AMBIGUOUS_TASK` when two tasks share words. Take the id from a `--json`
listing; don't guess it.

**Check what quick add understood.** `--json` returns the created task. Make sure
`due` and `projectId` match what the user asked for. A date phrase the parser
didn't understand stays in the title instead of becoming a due date. If that
happens, fix it with `td task update id:<id> --content … --due …`.

**`No API token found`** means `td` is not logged in. Tell the user to click
"Log in with Todoist" in the bar's Todoist panel, or to run `td auth login`
themselves. It is an interactive browser OAuth flow, so don't start it unasked.

**`td` exit codes are real.** Non-zero means it failed: report stderr as-is and
don't claim the item was saved.

## Writing the item

- **One task per todo.** If the user drops a compound request ("ogarnij X i Y"),
  add two items rather than one long one.
- **Match the user's language.** They write their todos in Polish; keep the text
  in the language they used.
- **Short and actionable:** a noun phrase or an imperative, sized to be readable
  in a bar widget. Push any elaboration into `--description`, not the title.
- **Don't editorialize.** Save what they asked for; don't invent due dates,
  priorities or follow-up items they didn't mention.

## Reporting back

Echo the exact text saved and where it went, e.g.
`zapisane: "setup t3code na telefonie" → Inbox`. When listing, render the tasks
as a plain list (overdue first), with the id alongside each item so a follow-up
"odhacz to drugie" can be resolved without another round trip.
