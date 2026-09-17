# handy — feature notes

2026-06-26: Added featureMeta + a feature test.

The feature uses `appimageTools.wrapType2` from a separately instantiated nixpkgs (not the perSystem `pkgs`) — this is a legacy pattern. The binary is `handy`.

Symptom: `handy --start-hidden --no-tray` launched via a niri bind may not work in a headless VM.
Cause: The AppImage needs a graphical environment (FUSE mount + Wayland/X11).
Fix: The feature test only checks the binary is on PATH (kind=gui), it does not start the process.

Symptom: The AppImage may need `fuse` or `fuse3` at runtime.
Cause: appimageTools.wrapType2 mounts the AppImage via FUSE.
Fix: Works on the real machine (nixos has fuse). Not tested in the headless VM.

## 2026-09-17 — an empty transcription usually means a dead microphone, not a broken handy

**Symptom:** `Mod+V` records, handy reports success, and nothing is typed. The
log (`~/.local/share/com.pais.handy/logs/handy.log`) shows the recording running
to completion and then:

```
Recording stopped and samples retrieved in 60.98ms, sample count: 0
Audio vector length: 0
Empty audio vector
Transcription completed in 33.46µs: ''
```

**Cause:** handy runs every frame through a Silero VAD (threshold 0.3, in
`managers/audio.rs`) and keeps only the frames it classifies as speech —
`audio_toolkit/audio/recorder.rs` drops `VadFrame::Noise` on the floor. So
`sample count: 0` is the VAD reporting *there was no speech in the signal*, not
a failure. Note the asymmetry: a **broken** VAD cannot produce this, because
`det.push_frame(samples).unwrap_or(VadFrame::Speech(samples))` treats an error
as speech and lets the whole recording through. Zero therefore means the VAD ran
fine and heard nothing.

The real cause was a wireless headset (SteelSeries Arctis 7) that was powered
off. Nothing in software shows this: ALSA and `wpctl` both report the source at
100% and unmuted, and PipeWire happily shows a live `alsa_capture.handy` stream
in state `running`, because the dongle keeps presenting the card regardless of
the headset. The Arctis also mutes its mic on the earcup, below anything the
host can observe.

**Fix / triage order.** `sample count` splits the problem in two, so read it
first:

- `sample count: 0` → the fault is *upstream* of handy. Check the microphone,
  the headset, and which source is the default. Handy and the model are fine.
- `sample count: <large>` but empty text → only now suspect handy or the model.

To measure the microphone directly, bypassing handy (peak well under
−50 dBFS across the whole window means no speech is arriving):

```
pw-record --target "$(wpctl status | ...)" --rate 16000 --channels 1 /tmp/mic.wav
```

For reference, a working handy recording in `recordings/` peaks around −7 dBFS;
a dead headset measured −59 dBFS.

This cannot be encoded in the feature test — the headless VM has no microphone,
which is why `kind = "gui"` only asserts the binaries are on PATH.

## 2026-09-17 — `Mod+V` needs handy in its own unit, and must wait for the signal handler

**Symptom:** pressing `Mod+V` when handy was not already running did nothing.
handy started, immediately died, and no recording happened. The previous bind was:

```
"Mod+V".spawn-sh = "pgrep -x handy || handy --start-hidden --no-tray; pkill -USR2 -x handy";
```

**Cause:** two independent defects, both invisible from the bind itself.

1. **niri tears down the scope.** Every niri bind runs in a transient systemd
   scope (`app-niri-<cmd>-<pid>.scope`) which systemd destroys as soon as the
   bound command exits. A handy started in the background belongs to that
   cgroup, so it is killed ~200 ms later, mid-startup. The journal shows it
   plainly:

   ```
   Started app-niri-handy\x2dtoggle-282213.scope.
   app-niri-handy-toggle-282213.scope: Consumed 401ms CPU time over 209ms wall clock time
   ```

   This is the same cgroup trap as running a rebuild from inside a terminal that
   the rebuild restarts: the fix is to hand the long-lived process to systemd.

2. **`pkill -USR2` raced the handler, and was too broad.** handy toggles
   recording on SIGUSR2, but until it installs the handler (~200 ms after a cold
   start) SIGUSR2 still has its default action — *terminate*. So the old bind's
   `pkill` immediately after spawning could kill handy rather than record.
   `pkill -x handy` also matches handy's short-lived helper processes, which
   never install a handler and therefore die from the signal.

**Fix:** `handy-toggle` (in `handy.nix`) does both jobs. It starts handy via
`systemd-run --user --unit=handy` so the process escapes the bind's scope, then
waits until a handy PID reports a SIGUSR2 handler before signalling that exact
PID. Readiness is read from the kernel rather than guessed:
`/proc/<pid>/status`'s `SigCgt` is a hex mask of caught signals, and bit 11
(0-indexed) is signal 12, SIGUSR2. Measured cold start: process visible at
116 ms, handler installed at 201 ms.

The wait is bounded by wall clock, not iteration count — each probe forks
`pgrep` and `awk`, so a 500-iteration loop with `sleep 0.02` actually ran ~23 s
against a stated 10 s ceiling.

Display variables are forwarded explicitly into the unit
(`--setenv=WAYLAND_DISPLAY=…`, `DISPLAY`, `XDG_RUNTIME_DIR`,
`XDG_SESSION_TYPE`). handy initialises GTK through XWayland, so **`DISPLAY` is
required** — without it the process aborts with
`Failed to initialize gtk backend!`. niri sets these for the processes it
spawns but does not carry them in its own `environ`, so they must be taken from
the bind's environment rather than reconstructed from niri's.
