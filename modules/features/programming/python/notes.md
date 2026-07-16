# feature notes — python

## 2026-06-26

Symptom: `python3 --version` may not find Python if `python314` is installed without a `python3` wrapper.
Cause: nixpkgs `python314` installs `python3.14` and `python3` as symlinks in the same derivation, so `python3` should be on PATH.
Fix: If the feature test fails on `python3 --version`, change the assertion to `python3.14 --version` — that's the canonical binary of the `python314` package.
