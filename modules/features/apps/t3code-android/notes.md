# t3code-android notes

## 2026-11-03: connecting a phone over wireless debugging

The Device panel lists any phone `adb devices -l` shows, next to emulators. Only
the first connection needs the phone in hand:

1. On the phone: Developer options → Wireless debugging → Pair device with
   pairing code.
2. `adb pair <ip>:<pairing-port> <code>`. The pairing port is not the connect
   port shown at the top of the Wireless debugging screen.
3. `adb connect <ip>:<connect-port>`, or wait for mDNS to do it.

The key lands in `~/.android/adbkey`, so it survives rebuilds. The phone must be
on the same LAN.

## 2026-11-03: the SDK must look complete to T3 Code

`LocalDeviceHost.ts` refuses Android outright without `emulator` and
`cmdline-tools/latest/bin/avdmanager`, although a physical phone never uses the
emulator. That is the reason for the ~2 GB closure (emulator 846 MB, JDK 473 MB).
No system images are installed, so no emulator can boot from this SDK.
