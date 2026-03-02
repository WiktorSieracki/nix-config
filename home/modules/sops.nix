{inputs, ...}: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  home.packages = with inputs.nixpkgs.legacyPackages.x86_64-linux; [
    sops
  ];

  sops = {
    # The age key file used to decrypt secrets (your user key for SOPS CLI)
    age.keyFile = "/home/wiktor/.config/sops/age/keys.txt";

    # The default sops file to use for secrets
    defaultSopsFile = ../../secrets.yaml;
    validateSopsFiles = false;

    secrets = {
      # This decrypts the "eduroamPassword" key from secrets.yaml
      eduroamPassword = {};
    };

    # someOption = config.sops.secrets.hello.path;
    # if home-manager switch fails because of sops try running:
    # systemctl --user reset-failed
  };
}
