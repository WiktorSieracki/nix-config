#!/usr/bin/env bash
# Install a host from this repository onto a mounted target, then leave the
# machine ready to run `nh os switch` on its first boot.
#
# Three things have to be true after a from-scratch install, and only the first
# happens on its own:
#   1. the system closure is on the disk            -- nixos-install
#   2. the SOPS key is in the account's ~/.ssh      -- otherwise every
#      secret-backed feature fails to activate at first boot
#   3. ~/.config/nix-config exists                  -- NH_FLAKE points there
set -euo pipefail

REPO_HTTPS="@httpsUrl@"
REPO_SSH="@sshUrl@"
REPO_FLAKE="@flakeRef@"
BW_ITEM="@bwItem@"
DEFAULT_USER="@primaryUser@"

usage() {
  cat <<'USAGE'
nixos-bootstrap -- install a nix-config host and set up its first boot

  nixos-bootstrap <host> [--user <login>] [--skip-install] [--skip-key]

Arguments:
  <host>            desktopNixos | laptopNixos

Options:
  --user <login>    account to set up (default: the repo's primary user)
  --skip-install    target is already installed; only place the key and checkout
  --skip-key        do not touch Bitwarden or ~/.ssh
  -h, --help        this text

Before running: partition the disk, mount the target at /mnt (with the ESP at
/mnt/boot), and bring up networking -- `nmtui` is on this image for that.

The Bitwarden CLI is not baked into this image (its closure is larger than the
release headroom); it is fetched with `nix run` when the key step runs.
USAGE
}

die() {
  echo "nixos-bootstrap: $*" >&2
  exit 1
}

host=""
login="$DEFAULT_USER"
skip_install=0
skip_key=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --user)
      [ $# -ge 2 ] || die "--user needs a value"
      login="$2"
      shift 2
      ;;
    --skip-install)
      skip_install=1
      shift
      ;;
    --skip-key)
      skip_key=1
      shift
      ;;
    -*)
      usage >&2
      die "unknown option: $1"
      ;;
    *)
      [ -z "$host" ] || die "more than one host given: $host and $1"
      host="$1"
      shift
      ;;
  esac
done

[ -n "$host" ] || {
  usage >&2
  die "no host given"
}
[ "$(id -u)" -eq 0 ] || die "must run as root (try: sudo nixos-bootstrap $host)"
mountpoint -q /mnt || die "/mnt is not a mountpoint -- partition and mount the target first"

# ── 1. install ───────────────────────────────────────────────────────────────
if [ "$skip_install" -eq 0 ]; then
  echo "==> installing $host onto /mnt"
  # accept-flake-config opts into the substituters declared in flake.nix, which
  # is how the closure comes out of the wiktor-nixos cache instead of being
  # built here.
  nixos-install \
    --flake "$REPO_FLAKE#$host" \
    --no-root-passwd \
    --option accept-flake-config true
else
  echo "==> skipping install"
fi

home="/mnt/home/$login"
[ -d "$home" ] || die "$home does not exist -- was $login created by the install?"

# The account's uid/gid only exist after the install has run its user
# activation, which is why everything below happens after step 1 rather than
# before it: writing files first would mean guessing the numbers.
uid="$(awk -F: -v u="$login" '$1 == u {print $3}' /mnt/etc/passwd)"
gid="$(awk -F: -v u="$login" '$1 == u {print $4}' /mnt/etc/passwd)"
[ -n "$uid" ] && [ -n "$gid" ] || die "no $login in /mnt/etc/passwd"

# ── 2. SOPS key out of Bitwarden ─────────────────────────────────────────────
if [ "$skip_key" -eq 0 ]; then
  echo "==> fetching the SSH key from Bitwarden (item: $BW_ITEM)"
  bw_bin="$(nix build --no-link --print-out-paths nixpkgs#bitwarden-cli)/bin/bw"

  # The session key stays in this process's environment and nowhere else: no
  # temp file, no shell history, and `bw logout` at the end.
  if ! session="$("$bw_bin" login --raw 2>/dev/null)"; then
    echo "    already logged in, unlocking instead"
    session="$("$bw_bin" unlock --raw)"
  fi
  export BW_SESSION="$session"

  "$bw_bin" sync >/dev/null

  # Item type 5 (SSH key) keeps the material in structured fields, not in notes.
  item="$("$bw_bin" get item "$BW_ITEM")"

  umask 077
  mkdir -p "$home/.ssh"
  printf '%s' "$item" | jq -er '.sshKey.privateKey' >"$home/.ssh/id_ed25519"
  printf '%s' "$item" | jq -er '.sshKey.publicKey' >"$home/.ssh/id_ed25519.pub"
  unset item

  # A truncated or wrong-item download would otherwise only surface at first
  # boot, as an unexplained sops failure. Compare the key type and body of the
  # derived public key against the stored one (the trailing comment differs).
  derived="$(ssh-keygen -y -f "$home/.ssh/id_ed25519" | awk '{print $1, $2}')"
  stored="$(awk '{print $1, $2}' "$home/.ssh/id_ed25519.pub")"
  if [ "$derived" != "$stored" ]; then
    rm -f "$home/.ssh/id_ed25519" "$home/.ssh/id_ed25519.pub"
    die "the private key does not match the public key in the vault item -- nothing written"
  fi

  "$bw_bin" logout >/dev/null 2>&1 || true
  unset BW_SESSION

  chown -R "$uid:$gid" "$home/.ssh"
  chmod 700 "$home/.ssh"
  echo "    key written to $home/.ssh/id_ed25519"
else
  echo "==> skipping the key step"
fi

# ── 3. the account's own checkout ────────────────────────────────────────────
checkout="$home/.config/nix-config"
if [ -e "$checkout" ]; then
  echo "==> $checkout already exists, leaving it alone"
else
  echo "==> cloning the config into $checkout"
  mkdir -p "$(dirname "$checkout")"
  git clone --quiet "$REPO_HTTPS" "$checkout"
  git -C "$checkout" remote set-url --push origin "$REPO_SSH"
  chown -R "$uid:$gid" "$home/.config"
fi

cat <<EOF

==> done.

Reboot into the installed system and log in as $login. Secrets decrypt on the
first boot because the key is already in place, and

    nh os switch

works straight away -- NH_FLAKE points at $checkout.
EOF
