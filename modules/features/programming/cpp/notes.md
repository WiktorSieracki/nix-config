# feature notes — cpp

## 2026-06-26

Symptom: `clang` comes from the nixpkgs `clang` package, but `clang-tools` provides separate tools (`clang-format`, `clang-tidy`). There's no point testing `clang-tidy --version` in the feature test, since it depends on the presence of an LLVM base — `clang --version` is enough as a smoke test.
Cause: The feature is HM-only (home.packages), so it requires `requires = ["wiktor"]` — without the wiktor user, HM isn't attached and the packages don't land on any user's PATH.
Fix: The feature test waits for `home-manager-wiktor.service` before the `su - wiktor -c '...'` assertions.
