# buzz — feature notes

Desktop client for [block/buzz](https://github.com/block/buzz), a self-hosted
Nostr-relay workspace for humans + AI agents.

## Packaging

- **No upstream nix package or flake.** Upstream builds via Hermit + `just`. We
  package the prebuilt release **`.deb`** from GitHub releases.
- **Use the `.deb`, not the AppImage.** The `.deb` ships *no* bundled libraries —
  just the binaries, declaring `libwebkit2gtk-4.1-0, libgtk-3-0` — so
  `autoPatchelfHook` links it against **nixpkgs' own webkitgtk**, which renders
  correctly. The AppImage bundles its own webkit and is a dead end on NVIDIA
  (see the dated entry below).
- The desktop app is a **Tauri** app (`libwebkit2gtk-4.1`). `wrapGAppsHook3`
  supplies GSettings schemas + the GStreamer plugin path.
- Ships several binaries: `buzz` (CLI), `buzz-desktop` (GUI), `buzz-agent`,
  `buzz-acp`, `buzz-dev-mcp`, `git-credential-nostr`. The `.desktop` entry's
  `Exec=buzz-desktop` matches the installed binary, so no rewriting is needed.

## Scope

This feature is **only the desktop client**. The full self-hosted relay
(Rust relay + Postgres + Redis + MinIO) is a separate, much larger effort and is
not packaged here.

## Updating the version

Bump `version` in `buzz.nix`, then refresh the hash:

```bash
nix-prefetch-url https://github.com/block/buzz/releases/download/v<VERSION>/Buzz_<VERSION>_amd64.AppImage
nix hash convert --hash-algo sha256 --to sri <BASE32_HASH>
```

Current: **v0.4.26** (released 2025-07-25).

## 2026-07-27 — brakujące biblioteki runtime (Tauri/webkit)

Objaw → `buzz-desktop` kończył się natychmiast błędem
`error while loading shared libraries` (kolejno `libzstd.so.1`, `libelf.so.1`, …).
Przyczyna → domyślny FHS `appimageTools` nie zawiera wszystkiego, co dociąga
zbundlowany webkit2gtk. Fix → `extraPkgs` z `zstd elfutils gmp libgpg-error
gst_all_1.gstreamer gst_all_1.gst-plugins-base` (gstreamer = backend mediów
webkita). Po tym łańcuch błędów znika.

## 2026-07-27 — ROZWIĄZANE: przepakowanie z `.deb` naprawiło puste okno

Fix na problem opisany niżej: porzucić `appimageTools`, wziąć **`.deb`** i
`autoPatchelfHook`. Deb nie ma żadnych zbundlowanych bibliotek, więc binarka
linkuje się do **nixpkgsowego `webkitgtk-2.52.5+abi=4.1`**, który ma działający
stos GL/GStreamer. Efekt: `WebKitWebProcess` **żyje**, zero błędów EGL, okno
renderuje pełny onboarding, i apka chodzi natywnie na Waylandzie
(App ID `buzz-desktop`, nie XWayland `Buzz-desktop`). Bonus: −237 MB względem
AppImage.

Do `buildInputs` trzeba było dołożyć `alsa-lib` (jedyna zależność, której
autoPatchelf nie znalazł).

**Pułapka: `gappsWrapperArgs` jako atrybut derywacji nie działa.** Ustawione jako
`gappsWrapperArgs = [ ... ];` jest **po cichu ignorowane** — `wrapGAppsHook`
czyta to jako tablicę basha, nie zmienną z stringiem. Objawiało się to tym, że
`GST_PLUGIN_SYSTEM_PATH_1_0` w ogóle nie trafiał do wrappera (sprawdzalne:
`strings $out/bin/buzz-desktop | grep GST_PLUGIN_SYSTEM_PATH_1_0` → 0 trafień),
a w logach dalej leciało `Missing decoder: MPEG-4 AAC` (apka odtwarza dźwięki
powiadomień w AAC). Poprawnie **dopisać w `preFixup`**:

```nix
preFixup = ''
  gappsWrapperArgs+=( --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "…" )
'';
```

Po tym log startowy jest całkowicie czysty (zero ostrzeżeń GStreamera).

## 2026-07-27 — PUSTE OKNO na AppImage: WebKitWebProcess pada (historyczne)

Objaw → apka startuje, okno **powstaje** (widoczne w `niri msg windows`,
App ID `Buzz-desktop`), ale jest **całkowicie przezroczyste** — żadnego UI.

Przyczyna → renderujący proces webkita **umiera**. Po starcie zostają tylko
`buzz-desktop` + `WebKitNetworkProcess`; **`WebKitWebProcess` znika**. Powód to
dwie luki w piaskownicy FHS `appimageTools`:

1. **Brak sterownika EGL.** `libEGL warning: pci id 10de:2803, driver (null)` →
   `egl: failed to create dri2 screen`. Rootfs FHS nie ma **ani jednego**
   `libEGL*` ani katalogu `/usr/share/glvnd/egl_vendor.d`, więc glvnd nie
   znajduje `libEGL_nvidia.so` (host ma je w `/run/opengl-driver`).
2. **Brak wtyczek GStreamera.** `GStreamer element appsink/appsrc/autoaudiosink
   not found` → seria `GStreamer-CRITICAL` / `G_IS_OBJECT assertion failed`
   w `WebKitWebProcess`.

Co **nie** pomogło (sprawdzone):
- `WEBKIT_DISABLE_DMABUF_RENDERER=1`, `WEBKIT_DISABLE_COMPOSITING_MODE=1`
- `__EGL_VENDOR_LIBRARY_DIRS` + `LD_LIBRARY_PATH=/run/opengl-driver/lib`
  (nie docierają do środka — `appimage-exec.sh` nadpisuje środowisko)
- `GST_PLUGIN_SYSTEM_PATH_1_0` na nixpkgsowe wtyczki — AppImage bundluje własne
  liby GStreamera, więc zewnętrzne wtyczki 1.28.4 nie pasują ABI i są odrzucane
- `LIBGL_ALWAYS_SOFTWARE=1` — **usuwa** błędy EGL, ale UI dalej się nie maluje

Wniosek → `appimageTools` to tu ślepa uliczka (zbundlowany webkit + brak
sterownika GPU w sandboxie). **Właściwy fix: przepakować z `.deb`**
(`autoPatchelfHook` + `wrapGAppsHook`) przeciw *nixpkgsowemu* `webkitgtk_4_1`
i `gst_all_1`, żeby apka używała systemowego, działającego stosu
webkit/GL/GStreamer zamiast własnego.

## 2026-07-27 — cichy exit 0 / brak okna przy uruchamianiu z automatyzacji

Objaw → po naprawie bibliotek `buzz-desktop` uruchomiony **detached**
(`systemd-run --user`, nawet z `WAYLAND_DISPLAY`/`DISPLAY`) kończy się czysto
(exit 0), bez logów (`RUST_LOG=debug` też nic) i bez okna w `niri msg windows`.
Dowód, że apka **działa**: przy pierwszym odpaleniu zainicjalizowała pełny profil
w `~/.local/share/xyz.block.buzz.app` (WebKitCache, `managed-agents.json` 559 KB,
`retention.db`, HSTS) — czyli webview realnie wystartował.
Przyczyna (hipoteza) → single-instance / keychain-lock
(`/tmp/buzz-keychain-1000-buzz-desktop.lock`): apka oczekuje interaktywnej sesji
logowania; odpalana z nie-interaktywnego harnessu/detached startuje jako primary,
tworzy lock, ale kolejne uruchomienia wychodzą natychmiast. Usunięcie locka nie
pomaga. **Wniosek: uruchamiać z launchera niri / terminala w realnej sesji**, nie
przez automatyzację.

Uwaga: przy pierwszym uruchomieniu apka tworzy `~/.local/bin/buzz` → symlink do
`…buzz-0.4.26-extracted/usr/bin/buzz` (surowy CLI, bez owinięcia w FHS). To
przesłania systemowego `buzz` w PATH. Jeśli `buzz` z shella nie działa —
to ten shadow; usuń symlink albo użyj pełnej ścieżki
`/run/current-system/sw/bin/buzz`.
