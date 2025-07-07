{ config, pkgs, ... }:

# Make sure you have the SSH keys generated and added to your GitHub/GitLab accounts.
# I store my SSH keys in ~/.ssh/id_ed25519 and ~/.ssh/id_ed25519.pub. and also in my password manager.
{
  programs.ssh = {
    enable = true;

    matchBlocks = {
      "github.com" = {
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
      };
      "gitlab.com" = {
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  services.ssh-agent.enable = true;

  home.file.".ssh/config".text = ''
    Host github.com
      IdentityFile ~/.ssh/id_ed25519
      User git

    Host gitlab.com
      IdentityFile ~/.ssh/id_ed25519
      User git
  '';
}
