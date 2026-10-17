#!/data/data/com.termux/files/usr/bin/bash
# Install legacy Jellyfin 10.10.7 on 32-bit ARM Termux using Debian/PRoot.
# Usage: bash ~/bin/setup-legacy-jellyfin.sh
set -Eeuo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
RAW_BASE="https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main"
LOG_DIR="$HOME/.local/share/media-server-logs"
CONFIG_DIR="$HOME/.config/termux-media-server"
BOOT_SCRIPT="$HOME/.termux/boot/00-start-media-server"

say() { printf '\n==> %s\n' "$*"; }
warn() { printf '\nWARNING: %s\n' "$*" >&2; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

TERMUX_ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
case "$TERMUX_ARCH" in
  arm|armhf|armv7|armv7l) ;;
  *)
    die "This legacy installer is for 32-bit ARM Termux (dpkg architecture 'arm'). Detected '$TERMUX_ARCH'. Use the native Jellyfin package on supported 64-bit Termux devices instead."
    ;;
esac

say "Installing Termux prerequisites"
pkg install -y proot-distro curl ffmpeg procps

mkdir -p "$HOME/bin" "$HOME/.termux/boot" "$LOG_DIR" "$CONFIG_DIR" "$PREFIX/bin"

say "Checking Debian container"
if debian_arch="$(proot-distro login debian -- dpkg --print-architecture 2>/dev/null)"; then
  if [[ "$debian_arch" != "armhf" ]]; then
    die "A Debian container already exists but reports '$debian_arch', not 'armhf'. It was not replaced. Back up anything important before changing or removing a container."
  fi
else
  proot-distro install debian:bookworm --architecture arm
  debian_arch="$(proot-distro login debian -- dpkg --print-architecture 2>/dev/null || true)"
  [[ "$debian_arch" == "armhf" ]] || die "Debian installation did not produce armhf (reported: ${debian_arch:-unknown})."
fi

say "Configuring official Jellyfin Debian repository and installing version 10.10.7"
proot-distro login debian -- /bin/bash -s <<'DEBIAN_SETUP'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl gnupg

install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key \
  | gpg --dearmor --yes -o /etc/apt/keyrings/jellyfin.gpg
chmod 0644 /etc/apt/keyrings/jellyfin.gpg

cat > /etc/apt/sources.list.d/jellyfin.sources <<'JELLYFIN_SOURCE'
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: bookworm
Components: main
Architectures: armhf
Signed-By: /etc/apt/keyrings/jellyfin.gpg
JELLYFIN_SOURCE

apt-get update
server_version="$(apt-cache madison jellyfin-server | awk '$3 == "10.10.7+deb12" { print $3; exit }')"
web_version="$(apt-cache madison jellyfin-web | awk '$3 == "10.10.7+deb12" { print $3; exit }')"
if [[ "$server_version" != "10.10.7+deb12" || "$web_version" != "10.10.7+deb12" ]]; then
  echo "Jellyfin 10.10.7+deb12 is not available for armhf from the configured repository." >&2
  echo "Available server versions:" >&2
  apt-cache madison jellyfin-server >&2 || true
  exit 1
fi

apt-get install -y "jellyfin-server=$server_version" "jellyfin-web=$web_version"
dpkg-query -W -f='${Package} ${Version} ${Architecture}\n' jellyfin-server jellyfin-web
DEBIAN_SETUP

say "Verifying Termux FFmpeg inside Debian/PRoot"
ffmpeg -version >/dev/null
proot-distro login debian --bind "$PREFIX:/termux" -- /termux/bin/ffmpeg -version >/dev/null

install_repo_file() {
  local repo_path="$1"
  local destination="$2"
  local mode="$3"
  local tmp
  tmp="$(mktemp)"
  curl -fsSL "$RAW_BASE/$repo_path" -o "$tmp"
  if [[ -f "$destination" ]] && ! cmp -s "$tmp" "$destination"; then
    cp -p "$destination" "$destination.backup.$(date +%Y%m%d%H%M%S)"
  fi
  install -m "$mode" "$tmp" "$destination"
  rm -f "$tmp"
}

say "Installing background launcher and refreshing service/status/boot scripts"
install_repo_file "start-legacy-jellyfin.sh" "$HOME/bin/start-legacy-jellyfin.sh" 700
install_repo_file "start-media.sh" "$HOME/bin/start-media.sh" 700
install_repo_file "media-status.sh" "$PREFIX/bin/media-status" 755
install_repo_file "boot-start-media.sh" "$BOOT_SCRIPT" 700

touch "$HOME/.bashrc"
SHELL_HOOK='bash "$HOME/bin/start-media.sh"'
if ! grep -Fqx "$SHELL_HOOK" "$HOME/.bashrc"; then
  printf '\n# Start configured media services when a Termux shell opens\n%s\n' "$SHELL_HOOK" >> "$HOME/.bashrc"
fi

touch "$CONFIG_DIR/legacy-jellyfin-enabled"
chmod 700 "$HOME/bin/start-legacy-jellyfin.sh" "$HOME/bin/start-media.sh" "$BOOT_SCRIPT"
chmod 755 "$PREFIX/bin/media-status"

say "Starting the media services"
bash "$HOME/bin/start-media.sh"

cat <<SUMMARY

LEGACY JELLYFIN SETUP COMPLETE
==============================
Jellyfin version: 10.10.7 (Debian Bookworm armhf)
Web interface:   http://127.0.0.1:8096
Remote interface: http://YOUR_PHONE_TAILSCALE_IP:8096
Launcher:         $HOME/bin/start-legacy-jellyfin.sh
Jellyfin log:     $LOG_DIR/jellyfin-legacy.log
Launcher log:     $LOG_DIR/jellyfin-launcher.log
Status command:   media-status
Manual start:     bash ~/bin/start-legacy-jellyfin.sh

The launcher uses Termux's FFmpeg inside Debian/PRoot because the packaged
Jellyfin FFmpeg binary may fail to load on Android. The web directory is
explicitly set to /usr/share/jellyfin/web.

For startup after reboot, install Termux:Boot from the same source as Termux
and open it once. Set Termux and Termux:Boot battery use to Unrestricted.
Android can still terminate background processes; no script can guarantee
that a process runs forever.
SUMMARY
