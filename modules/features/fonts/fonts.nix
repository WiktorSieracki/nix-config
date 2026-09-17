{
  # The system font set. Without this feature a host runs on nothing but
  # `fonts.enableDefaultPackages` (DejaVu, Liberation, FreeFont, Noto *CJK*,
  # emoji) — no modern UI face at all, and no Latin Noto.
  #
  # That gap is not cosmetic. Web/Electron UIs name their fonts the Apple and
  # Windows way (`-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui,
  # sans-serif` is t3code's stack, and half the web's). None of those names
  # exist on Linux, and fontconfig never answers "I don't have it" — stock
  # `65-nonlatin.conf` turns them into a long preference chain that starts
  # Adwaita Sans → Cantarell → Noto Sans UI → … and reaches DejaVu Sans only
  # near the end. With none of the head installed, the first family that *was*
  # present won: **Noto Sans CJK KR**, which has no precomposed ą ę ł ś ź ż.
  # Chromium then drew "ś" as `s` + a combining acute with no mark anchors —
  # an accent floating next to the letter. See notes.md for the measurement.
  #
  # The fix is to put a real UI font at the head of that chain rather than to
  # fight it: `adwaita-fonts` supplies Adwaita Sans / Adwaita Mono (GNOME's
  # Inter- and Iosevka-derived pair, full Polish coverage, 7 MB closure), and
  # Adwaita Sans is already first in the stock chain — so every Apple/Windows
  # UI name resolves to it with no custom XML.
  flake.modules.nixos.fonts = {pkgs, ...}: {
    fonts = {
      packages = [pkgs.adwaita-fonts];

      fontconfig.defaultFonts = {
        # Latin first, CJK last. The order matters for the generics too: the
        # CJK faces are fallback for the scripts they're for, not a candidate
        # for Polish text.
        sansSerif = ["Adwaita Sans" "DejaVu Sans" "Noto Sans CJK JP"];
        monospace = ["Adwaita Mono" "DejaVu Sans Mono" "Noto Sans Mono CJK JP"];
      };

      # The chain above covers the *sans* names but leaves a few Apple mono
      # names — which no generic ever rewrites — matching a proportional font
      # (`Menlo` resolved to Adwaita Sans). An app whose mono stack opens with
      # one of them would render code proportionally. `localConf` lands in
      # /etc/fonts/local.conf, loaded by 51-local.conf; that is early enough
      # for names the stock chains don't touch.
      fontconfig.localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <alias binding="same"><family>Menlo</family><prefer><family>Adwaita Mono</family></prefer></alias>
          <alias binding="same"><family>Monaco</family><prefer><family>Adwaita Mono</family></prefer></alias>
          <alias binding="same"><family>SF Mono</family><prefer><family>Adwaita Mono</family></prefer></alias>
        </fontconfig>
      '';
    };
  };

  flake.featureMeta.fonts = {
    # Pure system configuration: no binary, no unit. fontconfig itself (and
    # with it fc-match/fc-list) comes from the NixOS fontconfig module, which
    # is on in the core floor — this feature must not claim it.
    kind = "config";
    # localConf is only written when it is non-empty, so the file's existence
    # is the declaration that the mono aliases shipped.
    provides.files = ["/etc/fonts/local.conf"];
  };

  # feature test: the whole feature is a fontconfig *resolution table*, which
  # no `provides` key can express — so the script asserts the table itself,
  # plus the glyph coverage whose absence was the original bug.
  flake.featureTests.fonts = {
    testScript = ''
      def family(pattern):
          return machine.succeed("fc-match --format='%{family}' '" + pattern + "'").strip()

      # fc-match's pattern syntax treats "-" as a separator (family-size-style),
      # so the hyphenated CSS names have to be escaped or they silently test
      # something else ("ui-monospace" parses as family "ui").
      for pattern in [
          "Segoe UI",
          "system\\-ui",
          "\\-apple\\-system",
          "BlinkMacSystemFont",
          "sans-serif",
          "Helvetica Neue",
      ]:
          got = family(pattern)
          assert got == "Adwaita Sans", f"sans pattern {pattern!r} resolved to {got!r}"

      for pattern in [
          "monospace",
          "ui\\-monospace",
          "SFMono\\-Regular",
          "SF Mono",
          "Menlo",
          "Monaco",
          "Consolas",
      ]:
          got = family(pattern)
          assert got == "Adwaita Mono", f"mono pattern {pattern!r} resolved to {got!r}"

      # ą ę ł ń ó ś ź ż, precomposed. Noto Sans CJK KR — what "Segoe UI" used
      # to resolve to — carries only ń and ó; the rest came out as a base
      # letter plus a detached combining mark.
      for codepoint in ["0105", "0119", "0142", "0144", "00f3", "015b", "017a", "017c"]:
          for font in ["Adwaita Sans", "Adwaita Mono"]:
              machine.succeed(f"fc-list '{font}:charset={codepoint}' family | grep -q .")
    '';
  };
}
