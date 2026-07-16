# feature notes — java

## 2026-06-26

Symptom: `gradle --version` in the feature test starts a daemon and may exceed the VM timeout.
Cause: On its first invocation Gradle tries to fetch a wrapper or an init-script from the network.
Fix: In the VM the network is available, but Gradle runs offline because there's no project config — `gradle --version` alone doesn't run a build, it only verifies the install; the VM timeout (usually 5 min) is enough.
