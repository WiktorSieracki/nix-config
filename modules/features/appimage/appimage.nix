{
  # Escape hatch for software that ships only as an AppImage (vendor tools,
  # exam clients, betas). With binfmt registered, `./Foo.AppImage` just runs:
  # the kernel hands it to appimage-run, which provides the FHS environment
  # NixOS lacks. nix-ld in the core floor covers plain prebuilt ELF binaries.
  flake.modules.nixos.appimage = {
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };

  flake.featureMeta.appimage = {
    kind = "cli";
    provides = {
      systemBins = ["appimage-run"];
      files = ["/proc/sys/fs/binfmt_misc/appimage_type_2"];
    };
  };

  # feature test: `provides` checks the binfmt handler is registered. Then
  # execute a file carrying only the AppImage type-2 magic: without the
  # handler the kernel answers "Exec format error"; with it the file reaches
  # appimage-run, whose readelf probe rejects the bogus header (appimage-run
  # still exits 0 there, so the output is what tells the two cases apart).
  flake.featureTests.appimage = {
    testScript = ''
      reg = machine.succeed("cat /proc/sys/fs/binfmt_misc/appimage_type_2")
      assert reg.startswith("enabled"), reg

      machine.succeed("printf '\\177ELF\\002\\001\\001\\000AI\\002' > /tmp/fake.AppImage && chmod +x /tmp/fake.AppImage")
      _, out = machine.execute("/tmp/fake.AppImage 2>&1")
      assert "Exec format error" not in out, f"binfmt did not dispatch:\n{out}"
      assert "readelf" in out, f"appimage-run was not reached:\n{out}"
    '';
  };
}
