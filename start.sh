
# install nix
sh <(curl -L https://nixos.org/nix/install) --no-daemon

# run nix-shell with home-manager
nix-shell -p home-manager

# activate system
home-manager switch
