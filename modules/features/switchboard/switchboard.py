#!/usr/bin/env python3
"""Switchboard — a TUI for managing per-host feature lists of this nix-config.

Real hosts keep their enabled features in modules/hosts/<host>/features.json
(ADR 0003). Switchboard edits those data files — never .nix. It always writes
the full transitive closure of `requires`, because the loader hard-fails on
gaps (ADR 0002).
"""

import argparse
import asyncio
import json
import os
import shlex
import socket
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

__version__ = "0.1.0"

# Real hosts only — image hosts (iso/vm) keep inline lists and are not
# Switchboard's target (ADR 0003).
HOSTS = {
    "desktopNixos": "modules/hosts/desktop-nixos/features.json",
    "laptopNixos": "modules/hosts/laptop-nixos/features.json",
}

UPDATE_FLAKE = "update-flake"


# ── repo helpers ─────────────────────────────────────────────────────────────


def features_path(repo: Path, host: str) -> Path:
    return repo / HOSTS[host]


def read_features(repo: Path, host: str) -> list[str]:
    return json.loads(features_path(repo, host).read_text())


def write_features(repo: Path, host: str, features: list[str]) -> None:
    # Same shape as the existing files: pretty-printed, one name per line,
    # trailing newline.
    features_path(repo, host).write_text(json.dumps(features, indent=2) + "\n")


def requires_closure(meta: dict, names: list[str]) -> set[str]:
    """Transitive closure of `requires` over featureMeta (start names excluded
    unless they require each other)."""
    seen: set[str] = set()
    stack = list(names)
    while stack:
        for dep in meta.get(stack.pop(), {}).get("requires", []):
            if dep not in seen:
                seen.add(dep)
                stack.append(dep)
    return seen


def feature_diff(old: list[str], new: list[str]) -> tuple[list[str], list[str]]:
    added = [f for f in new if f not in old]
    removed = [f for f in old if f not in new]
    return added, removed


def lock_inputs(lock: dict) -> dict[str, dict]:
    """Map of top-level flake input name -> its `locked` attrs."""
    nodes = lock["nodes"]
    out = {}
    for name, key in nodes[lock["root"]].get("inputs", {}).items():
        if isinstance(key, str):  # lists are `follows` references
            out[name] = nodes.get(key, {}).get("locked", {})
    return out


def lock_diff(before: dict, after: dict) -> list[str]:
    """Human-readable old→new lines for inputs that changed in flake.lock."""

    def fmt(locked: dict) -> str:
        rev = (locked.get("rev") or locked.get("narHash") or "?")[:12]
        ts = locked.get("lastModified")
        date = (
            datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%d")
            if ts
            else "?"
        )
        return f"{rev} ({date})"

    b, a = lock_inputs(before), lock_inputs(after)
    return [
        f"{name}: {fmt(b.get(name, {}))} → {fmt(a.get(name, {}))}"
        for name in sorted(set(b) | set(a))
        if b.get(name) != a.get(name)
    ]


# ── TUI ──────────────────────────────────────────────────────────────────────
# Textual is imported lazily so `--version` / `--help` work in any environment
# (e.g. the headless Próba VM) without touching terminal machinery.


def build_app(repo: Path):
    from textual import work
    from textual.app import App, ComposeResult
    from textual.binding import Binding
    from textual.containers import Vertical
    from textual.screen import Screen
    from textual.widgets import (
        Footer,
        Header,
        Input,
        OptionList,
        SelectionList,
        Static,
    )
    from textual.widgets.option_list import Option
    from textual.widgets.selection_list import Selection

    def run_in_terminal(app: App, cmd: list[str]) -> int:
        """Suspend the TUI and run `cmd` in the repo with the real terminal
        (streaming output). Pauses afterwards so the output stays readable."""
        with app.suspend():
            print(f"\n$ {shlex.join(cmd)}", flush=True)
            try:
                rc = subprocess.call(cmd, cwd=repo)
            except FileNotFoundError as exc:
                print(exc)
                rc = 127
            try:
                input(f"\n[switchboard] exit code {rc} — press Enter to return ")
            except EOFError:
                pass
        return rc

    def git_commit(app: App, paths: list[str], message: str) -> None:
        add = subprocess.run(
            ["git", "add", "--", *paths], cwd=repo, capture_output=True, text=True
        )
        commit = subprocess.run(
            ["git", "commit", "-m", message], cwd=repo, capture_output=True, text=True
        )
        if add.returncode == 0 and commit.returncode == 0:
            app.notify(f"Committed: {message}")
        else:
            err = (add.stderr + commit.stdout + commit.stderr).strip()
            app.notify(f"git commit failed: {err[-300:]}", severity="error")

    class FinaleScreen(Screen):
        """Post-save / post-update screen: apply locally (nh os test/switch),
        or verify a foreign host with a dry-run build; optionally commit."""

        BINDINGS = [
            Binding("t", "test", "nh os test"),
            Binding("s", "switch", "nh os switch"),
            Binding("c", "commit", "Commit"),
            Binding("escape", "done", "Done"),
        ]

        def __init__(
            self,
            body: str,
            apply_host: str | None,  # host name if this machine can apply it
            verify_host: str | None,  # foreign host to dry-run build for
            commit_paths: list[str],
            commit_message: str,
            commit_ready: bool,
        ) -> None:
            super().__init__()
            self.body = body
            self.apply_host = apply_host
            self.verify_host = verify_host
            self.commit_paths = commit_paths
            self.commit_message = commit_message
            self.commit_ready = commit_ready

        def compose(self) -> ComposeResult:
            yield Header()
            yield Static(self.body, id="finale-body")
            yield Footer()

        def check_action(self, action: str, parameters: tuple) -> bool | None:
            if action in ("test", "switch"):
                return self.apply_host is not None
            if action == "commit":
                return self.commit_ready
            return True

        def on_mount(self) -> None:
            if self.verify_host:
                self.call_after_refresh(self.verify_foreign)

        def verify_foreign(self) -> None:
            target = f"{repo}#nixosConfigurations.{self.verify_host}.config.system.build.toplevel"
            rc = run_in_terminal(self.app, ["nix", "build", target, "--dry-run"])
            if rc == 0:
                self.notify(f"Saved — apply it on {self.verify_host}.")
            else:
                self.notify(
                    f"Saved, but the dry-run build for {self.verify_host} failed "
                    f"(exit {rc}) — check the config before applying.",
                    severity="error",
                )

        def action_test(self) -> None:
            rc = run_in_terminal(self.app, ["nh", "os", "test", str(repo)])
            if rc == 0:
                self.notify("nh os test succeeded (no commit after a test).")
            else:
                self.notify(f"nh os test failed (exit {rc}).", severity="error")

        def action_switch(self) -> None:
            rc = run_in_terminal(self.app, ["nh", "os", "switch", str(repo)])
            if rc == 0:
                self.commit_ready = True
                self.refresh_bindings()
                self.notify("nh os switch succeeded — press c to commit.")
            else:
                self.notify(f"nh os switch failed (exit {rc}).", severity="error")

        def action_commit(self) -> None:
            git_commit(self.app, self.commit_paths, self.commit_message)
            self.commit_ready = False
            self.refresh_bindings()

        def action_done(self) -> None:
            self.app.pop_to_main()

    class ConfirmScreen(Screen):
        """Feature diff for a host; saving hands over to the finale."""

        BINDINGS = [
            Binding("y", "save", "Save"),
            Binding("escape", "back", "Back"),
        ]

        def __init__(self, host: str, old: list[str], new: list[str]) -> None:
            super().__init__()
            self.host = host
            self.old = old
            self.new = new

        def compose(self) -> ComposeResult:
            added, removed = feature_diff(self.old, self.new)
            lines = [f"Changes for [b]{self.host}[/b]:", ""]
            lines += [f"[green]+{f}[/green]" for f in added]
            lines += [f"[red]−{f}[/red]" for f in removed]
            yield Header()
            yield Static("\n".join(lines), id="confirm-body")
            yield Footer()

        def action_back(self) -> None:
            self.app.pop_screen()

        def action_save(self) -> None:
            write_features(repo, self.host, self.new)
            added, removed = feature_diff(self.old, self.new)
            diff = " ".join([f"+{f}" for f in added] + [f"-{f}" for f in removed])
            local = self.host == socket.gethostname()
            self.app.switch_screen(
                FinaleScreen(
                    body=(
                        f"Saved {HOSTS[self.host]} ({diff}).\n\n"
                        + (
                            "Apply it on this machine with t (test) or s (switch)."
                            if local
                            else f"This machine is not {self.host} — running a "
                            "dry-run build as an eval check."
                        )
                    ),
                    apply_host=self.host if local else None,
                    verify_host=None if local else self.host,
                    commit_paths=[HOSTS[self.host]],
                    commit_message=f"switchboard: {self.host} {diff}",
                    commit_ready=not local,
                )
            )

    class HostScreen(Screen):
        """Feature catalog for one host: checkboxes + live search."""

        BINDINGS = [
            Binding("ctrl+s", "review", "Review & save"),
            Binding("escape", "back", "Back (discard)"),
        ]

        def __init__(self, host: str) -> None:
            super().__init__()
            self.host = host
            self.original = read_features(repo, host)
            self.enabled = list(self.original)  # order preserved for the file
            self.meta: dict = {}
            self.search = ""
            self._rebuilding = False

        def compose(self) -> ComposeResult:
            yield Header()
            with Vertical():
                yield Input(placeholder="Search features…", id="search")
                yield SelectionList(id="features")
            yield Footer()

        def on_mount(self) -> None:
            self.sub_title = f"{self.host} — loading featureMeta…"
            self.load_meta()

        @work(exclusive=True)
        async def load_meta(self) -> None:
            proc = await asyncio.create_subprocess_exec(
                "nix",
                "eval",
                f"{repo}#featureMeta",
                "--json",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            out, err = await proc.communicate()
            if proc.returncode != 0:
                self.sub_title = self.host
                self.notify(
                    f"nix eval featureMeta failed: {err.decode()[-300:]}",
                    severity="error",
                )
                return
            self.meta = json.loads(out)
            self.sub_title = self.host
            self.rebuild()

        def all_features(self) -> list[str]:
            # featureMeta is the catalog; keep any file-only strays visible too.
            return sorted(set(self.meta) | set(self.enabled))

        def rebuild(self) -> None:
            lst = self.query_one("#features", SelectionList)
            highlighted = lst.highlighted
            self._rebuilding = True
            try:
                lst.clear_options()
                for name in self.all_features():
                    if self.search and self.search not in name.lower():
                        continue
                    kind = self.meta.get(name, {}).get("kind", "?")
                    lst.add_option(
                        Selection(
                            f"{name} [dim]({kind})[/dim]",
                            name,
                            initial_state=name in self.enabled,
                        )
                    )
            finally:
                self._rebuilding = False
            if highlighted is not None and lst.option_count:
                lst.highlighted = min(highlighted, lst.option_count - 1)

        def on_input_changed(self, event: Input.Changed) -> None:
            self.search = event.value.strip().lower()
            self.rebuild()

        def on_selection_list_selection_toggled(
            self, event: SelectionList.SelectionToggled
        ) -> None:
            if self._rebuilding:
                return
            name = event.selection.value
            if name in self.query_one("#features", SelectionList).selected:
                self.enable(name)
            else:
                self.disable(name)

        def enable(self, name: str) -> None:
            pulled = [
                dep
                for dep in requires_closure(self.meta, [name])
                if dep not in self.enabled
            ]
            self.enabled.append(name)
            self.enabled.extend(pulled)  # the file gets the full closure
            if pulled:
                self.notify(
                    f"Also enabled (required by {name}): {', '.join(sorted(pulled))}"
                )
                self.rebuild()  # show the auto-selected deps

        def disable(self, name: str) -> None:
            # The file always holds a full closure, so checking *direct*
            # requires of enabled features finds every dependent.
            dependents = sorted(
                g
                for g in self.enabled
                if g != name and name in self.meta.get(g, {}).get("requires", [])
            )
            if dependents:
                self.notify(
                    f"Cannot disable {name} — required by: {', '.join(dependents)}",
                    severity="warning",
                )
                self.rebuild()  # re-check the blocked checkbox
                return
            self.enabled.remove(name)
            # Deps that were auto-pulled for `name` stay enabled on purpose.

        def action_review(self) -> None:
            # Keep the file's existing order; genuinely new names go last (in
            # the order they were enabled). A toggle off+on must not reorder.
            new = [f for f in self.original if f in self.enabled] + [
                f for f in self.enabled if f not in self.original
            ]
            if new == self.original:
                self.notify("No changes.")
                return
            self.app.push_screen(ConfirmScreen(self.host, self.original, new))

        def action_back(self) -> None:
            self.app.pop_screen()

    class SwitchboardApp(App):
        TITLE = "Switchboard"
        CSS = """
        #search { margin: 0 1; }
        #features { margin: 0 1; }
        #home-info, #confirm-body, #finale-body { margin: 1 2; }
        """
        BINDINGS = [Binding("q", "quit", "Quit")]

        def compose(self) -> ComposeResult:
            yield Header()
            yield Static(
                f"Flake: {repo}\nThis machine: {socket.gethostname()}",
                id="home-info",
            )
            options = [Option(host, id=host) for host in HOSTS]
            options.append(Option("Update flake", id=UPDATE_FLAKE))
            yield OptionList(*options, id="home-menu")
            yield Footer()

        def on_option_list_option_selected(
            self, event: OptionList.OptionSelected
        ) -> None:
            if event.option.id == UPDATE_FLAKE:
                self.update_flake()
            else:
                self.push_screen(HostScreen(event.option.id))

        def update_flake(self) -> None:
            lock_path = repo / "flake.lock"
            before = json.loads(lock_path.read_text())
            rc = run_in_terminal(self, ["nix", "flake", "update"])
            if rc != 0:
                self.notify(f"nix flake update failed (exit {rc}).", severity="error")
                return
            after = json.loads(lock_path.read_text())
            changes = lock_diff(before, after)
            if not changes:
                self.notify("All flake inputs already up to date.")
                return
            host = socket.gethostname()
            local = host in HOSTS
            self.push_screen(
                FinaleScreen(
                    body="Updated flake inputs:\n\n"
                    + "\n".join(changes)
                    + (
                        "\n\nApply on this machine with t (test) or s (switch)."
                        if local
                        else f"\n\nThis machine ({host}) is not a managed host."
                    ),
                    apply_host=host if local else None,
                    verify_host=None,
                    commit_paths=["flake.lock"],
                    commit_message="switchboard: update flake inputs",
                    commit_ready=not local,
                )
            )

        def pop_to_main(self) -> None:
            while len(self.screen_stack) > 1:
                self.pop_screen()

    return SwitchboardApp()


# ── CLI ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        prog="switchboard",
        description="TUI for managing NixOS host feature lists (features.json).",
    )
    parser.add_argument(
        "--version", action="version", version=f"switchboard {__version__}"
    )
    parser.add_argument(
        "--flake",
        default=os.environ.get(
            "SWITCHBOARD_FLAKE", os.path.expanduser("~/.config/nix-config")
        ),
        help="path to the nix-config repo (default: ~/.config/nix-config, "
        "override with $SWITCHBOARD_FLAKE)",
    )
    args = parser.parse_args(argv)

    repo = Path(args.flake).expanduser().resolve()
    if not (repo / "flake.nix").is_file():
        sys.exit(f"switchboard: no flake.nix in {repo} (use --flake or $SWITCHBOARD_FLAKE)")
    missing = [p for h in HOSTS for p in [features_path(repo, h)] if not p.is_file()]
    if missing:
        sys.exit(f"switchboard: missing host feature lists: {', '.join(map(str, missing))}")

    build_app(repo).run()


if __name__ == "__main__":
    main()
