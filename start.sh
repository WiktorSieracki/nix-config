
# install nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |   sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# run nix-shell with home-manager
nix-shell -p home-manager --command home-manager switch -b backup --impure
