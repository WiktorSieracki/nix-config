---
name: todo
description: >-
  Manages the user's personal todo list — their Todoist account, driven by the
  official `td` CLI and shown in the noctalia bar and on their phone. Use
  whenever the user wants something kept for later instead of done now, even
  if they never say "todo" and even when it is one clause of a message that
  asks for something else — deferring work mid-conversation ("zróbmy to
  później", "odłóżmy to na potem", "nie teraz, wrócimy do tego", "zostawmy to
  na później", "to na potem") or asking to save a task ("zapisz to jako do
  zrobienia", "dodaj todo", "todo: …", "wrzuć na listę", "zanotuj żebym…",
  "remind me to…"). Also for "co mam na liście" and ticking items off. Not for
  TODO comments in code, the agent's own step plan, "first X, then Y" inside
  the current task, GitHub issues, notes, or "przypomnij mi jak…" questions.
allowed-tools:
  - Bash
---

# Todo

The user's todo list is **Todoist**. There is no local list: the noctalia bar
widget (`plugin:todoist`) and the phone app both read the same account, so
anything written with `td` shows up everywhere on the next sync.

## Deferred work: "zróbmy to później"

When the user pushes something from this conversation to later, the deferral
*is* the request: save it straight away, without asking "czy zapisać?". Confirm
in one line, then carry on with whatever else the same message asked for. Don't
start the deferred work.

The item has to make sense weeks from now, outside this conversation:

- **Title**: the concrete next action, verb first, in the user's language.
  `Dodać cachix jako binary cache do CI nix-config`, not `Zrobić to później` or
  `cachix`.
- **Description**: only when the item is about work in this session (code, a
  bug, an idea you discussed). Write one or two sentences on what was decided
  and why. Then say where: the repo (`git rev-parse --show-toplevel`), the
  branch, the files involved, and anything already found, like an error message
  or the option you proposed. Personal errands ("zadzwonić do dentysty") get no
  description.

```bash
td task add --json --stdin -- "Dodać cachix jako binary cache do CI nix-config" <<'EOF'
Z rozmowy o wolnym CI: feature-tests budują ~59 testów VM po kolei na jednym
runnerze; cachix-action dałby cache między runami.
Repo: ~/.config/nix-config (main) · .github/workflows/feature-tests.yaml
EOF
```

If "to" could mean more than one open topic, save the most recent one and name
it in the confirmation so the user can correct it.

## Commands

```bash
td add --json -- "Kupić mleko jutro p2 #Zakupy"  # quick add: parses date/priority/project from the text
td task add --json --stdin -- "Title" <<<"…"     # explicit fields; the only way to attach a description
td today --json                                  # due today + overdue
td upcoming 7 --json                             # next 7 days (and overdue)
td inbox --json
td task list --project "Praca" --json
td task view id:<id> --json
td task complete id:<id>
td task uncomplete id:<id>
td task update id:<id> --content "…" --due "friday" --priority p2 --description "…"
td task delete id:<id> --yes                     # destructive — confirm with the user first
```

Quick-add syntax inside the text: a date in natural language ("tomorrow",
"mon 9:00", "every friday"), `p1`–`p4` for priority (p1 is the most urgent),
`#Project`, `@label`. Without a project it lands in the Inbox.

`td add` takes no field options. `--description`, `--due` and `--project` exist
only on `td task add`, which stores the title verbatim, without quick-add
parsing. So when there is a description, pass the date as `--due "tomorrow"` and
the project as `--project "…"`, and only if the user gave them.

Then nudge the bar so it doesn't wait for its 60-second poll:

```bash
WAYLAND_DISPLAY=wayland-1 noctalia-ipc call plugin:todoist refresh
```

That nudge is cosmetic: if it fails, say nothing about it.

## Gotchas

**Options go before `--`, the title after it.** Everything after `--` is task
text, so a `--description` placed there ends up in the title. The `--` itself
keeps a title that starts with a dash ("-5 kg") from being read as a flag.

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
  in a bar widget. Elaboration goes in the description, not the title.
- **Don't editorialize.** Save what they asked for. The description records what
  was said or found in the conversation. Don't add new ideas, due dates,
  priorities or follow-up items they didn't mention.

## Reporting back

Echo the exact text saved and where it went, e.g.
`zapisane: "setup t3code na telefonie" → Inbox`. When listing, render the tasks
as a plain list (overdue first), with the id alongside each item so a follow-up
"odhacz to drugie" can be resolved without another round trip.
