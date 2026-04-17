{inputs, ...}: {
  flake.modules = {
    nixos.sops = {pkgs, ...}: {
      imports = [
        inputs.sops-nix.nixosModules.sops
      ];

      environment.systemPackages = with pkgs; [
        sops
      ];

      sops = {
        # The age key file used to decrypt secrets (your user key for SOPS CLI)
        age.sshKeyPaths = ["/home/wiktor/.ssh/id_ed25519"];

        # The default sops file to use for secrets
        defaultSopsFile = ../../secrets.yaml;
        validateSopsFiles = false;

        secrets = {
          eduroamPassword = {};
          studentEmail = {};
        };

        # someOption = config.sops.secrets.hello.path;
        # if home-manager switch fails because of sops try running:
        # systemctl --user reset-failed
      };
    };
    homeManager.sops = {
      imports = [
        inputs.sops-nix.homeManagerModules.sops
      ];

      sops.secrets = {
        eduroamPassword = {};
        studentEmail = {};
      };

      sops = {
        age.sshKeyPaths = ["/home/wiktor/.ssh/id_ed25519"];
        defaultSopsFile = ../../secrets.yaml;
        validateSopsFiles = false;
      };
    };
  };
}
