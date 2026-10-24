#!/usr/bin/env python3
"""Evals for the `todo` agent skill (../todo/SKILL.md). See ../notes.md.

Each query goes through a fresh `claude -p` with the user's real config, so the
whole skill listing competes for the trigger, the way it does in a real session.
It runs inside a throwaway clone with stub/ first on PATH and a fake
TODOIST_API_TOKEN, so nothing can reach the real Todoist account or GitHub.

    python3 harness.py triggers.json NAME              # did Skill(todo) fire?
    python3 harness.py behavior.json NAME --full       # what got saved, and the reply
    python3 harness.py triggers.json NAME --installed  # baseline: the deployed skill

By default ~/.claude/skills/todo is pointed at the working copy for the run and
restored afterwards. Costs real model calls: not part of `nix flake check`.
"""

import argparse
import json
import os
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
WORK = Path("/tmp/todo-skill-eval")
LINK = Path.home() / ".claude/skills/todo"

# Skill must be pre-allowed or -p refuses to load it. td/gh are stubs and the
# rest is read-only, so nothing outside the scratch clone can change.
BASE = ["--permission-mode", "default", "--max-turns", "10",
        "--allowedTools", "Skill", "Bash(td *)", "Bash(td:*)", "Bash(noctalia-ipc *)",
        "Bash(git status*)", "Bash(git branch*)", "Bash(git rev-parse*)", "Bash(git log*)",
        "Bash(wc *)", "Bash(pwd)", "Bash(date*)"]


def scratch_repo():
    repo = WORK / "repo"
    if not repo.exists():
        root = subprocess.check_output(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"],
                                       text=True).strip()
        subprocess.run(["git", "clone", "-q", "--local", root, str(repo)], check=True)
        subprocess.run(["git", "-C", str(repo), "remote", "set-url", "origin", "/nonexistent"],
                       check=True)
    return repo


def run_one(q, run_idx, outdir, repo, timeout, full):
    rid = f"{q['id']}-{run_idx}"
    td_log = outdir / f"{rid}.td.log"
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    env.update(PATH=f"{HERE / 'stub'}:{env['PATH']}", TODOIST_API_TOKEN="fake-eval-token",
               TD_LOG=str(td_log))
    cmd = ["claude", "-p", q["query"], "--output-format", "stream-json", "--verbose", *BASE]
    if q.get("setup"):
        # Two-turn scenario: an earlier turn builds the context the deferral
        # refers to, then the real query resumes that session.
        first = subprocess.run(["claude", "-p", q["setup"], "--output-format", "json", *BASE],
                               capture_output=True, text=True, cwd=repo, env=env, timeout=timeout)
        setup = json.loads(first.stdout)
        cmd += ["--resume", setup["session_id"]]
        (outdir / f"{rid}.setup.txt").write_text(setup.get("result") or "")

    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                         cwd=repo, env=env, text=True)
    timer = threading.Timer(timeout, p.kill)
    timer.start()
    skills, bash, triggered, result = [], [], False, None
    with open(outdir / f"{rid}.jsonl", "w") as transcript:
        for line in p.stdout:
            transcript.write(line)
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
            if ev.get("type") == "assistant":
                for c in ev.get("message", {}).get("content", []):
                    if c.get("type") != "tool_use":
                        continue
                    inp = c.get("input", {})
                    if c["name"] == "Skill":
                        skills.append(inp.get("skill", ""))
                        triggered |= inp.get("skill") == "todo"
                    elif c["name"] == "Read":
                        triggered |= "/skills/todo/" in inp.get("file_path", "")
                    elif c["name"] == "Bash":
                        bash.append(inp.get("command", ""))
                if triggered and not full:
                    p.kill()
                    break
            elif ev.get("type") == "result":
                result = ev.get("result")
    p.wait()
    timer.cancel()
    state = Path(f"{td_log}.state.json")
    return {"id": q["id"], "run": run_idx, "triggered": triggered, "skills": skills,
            "bash": bash, "td": td_log.read_text().splitlines() if td_log.exists() else [],
            "saved": list(json.loads(state.read_text()).values()) if state.exists() else [],
            "result": result}


def report(queries, runs, label, full):
    correct = 0
    for q in queries:
        mine = [r for r in runs if r["id"] == q["id"]]
        hits = sum(r["triggered"] for r in mine)
        ok = (hits / len(mine) >= 0.5) == q["should_trigger"]
        correct += ok
        print(f"{'PASS' if ok else 'FAIL'}  {q['id']:<22} should={str(q['should_trigger']):<5} "
              f"triggered={hits}/{len(mine)}")
        for r in mine if full else []:
            for t in r["saved"]:
                due = (t.get("due") or {}).get("string")
                print(f"      saved: {t['content']!r} due={due!r} project={t['projectId']}")
                for line in t["description"].splitlines():
                    print(f"             | {line}")
            print(f"      reply: {(r['result'] or '').strip()[:300]!r}")
    print(f"\n{label}: {correct}/{len(queries)} queries correct")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("queries")
    ap.add_argument("label")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--workers", type=int, default=5)
    ap.add_argument("--timeout", type=int, default=240)
    ap.add_argument("--full", action="store_true", help="let the turn finish; show what was saved")
    ap.add_argument("--installed", action="store_true", help="test the deployed skill as-is")
    ap.add_argument("--only", nargs="*", help="query ids to run")
    a = ap.parse_args()

    queries = json.loads((HERE / a.queries).read_text())
    if a.only:
        queries = [q for q in queries if q["id"] in a.only]
    outdir = WORK / "runs" / a.label
    outdir.mkdir(parents=True, exist_ok=True)
    repo = scratch_repo()

    original = os.readlink(LINK) if LINK.is_symlink() else None
    if not a.installed:
        if original is None:
            raise SystemExit(f"{LINK} is not a symlink; refusing to replace it")
        tmp = LINK.with_name("todo.eval-swap")
        tmp.symlink_to(HERE.parent / "todo")
        tmp.replace(LINK)
    try:
        jobs = [(q, r) for q in queries for r in range(a.runs)]
        with ThreadPoolExecutor(a.workers) as ex:
            runs = list(ex.map(lambda j: run_one(*j, outdir, repo, a.timeout, a.full), jobs))
    finally:
        if not a.installed:
            tmp = LINK.with_name("todo.eval-swap")
            tmp.symlink_to(original)
            tmp.replace(LINK)

    report(queries, runs, a.label, a.full)
    (outdir / "results.json").write_text(json.dumps(runs, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
