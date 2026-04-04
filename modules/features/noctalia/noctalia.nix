{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages.myNoctalia = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
      inherit pkgs;
      settings =
        (builtins.fromJSON
          (builtins.readFile ./noctalia.json)).settings;
    };
  };

  # To update the `noctalia.json` file, run the following command:
  # $ nix run nixpkgs#noctalia-shell ipc call state all > ./modules/features/noctalia/noctalia.json
}
