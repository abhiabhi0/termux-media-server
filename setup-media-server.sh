#!/data/data/com.termux/files/usr/bin/bash
# One-time Android + Termux Media Server setup.
# Usage: curl -fsSL https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main/setup-media-server.sh -o "$HOME/setup-media-server.sh" && bash "$HOME/setup-media-server.sh"
set -Eeuo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
FB_DIR="$HOME/.config/filebrowser"
FB_DB="$FB_DIR/filebrowser.db"
LOG_DIR="$HOME/.local/share/media-server-logs"
START_SCRIPT="$HOME/bin/start-media.sh"
BOOT_SCRIPT="$HOME/.termux/boot/00-start-media-server"
SSH_SETUP_MARKER="$HOME/.config/termux-media-server/ssh-password-checked"
BASHRC="$HOME/.bashrc"
RAW_BASE="https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main"

say() { printf '\n==> %s\n' "$*"; }
warn() { printf '\nWARNING: %s\n' "$*" >&2; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARCH="$(uname -m)"
case "$ARCH" in
  aarch64|arm64) FB_ARCH="arm64" ;;
  x86_64|amd64)  FB_ARCH="amd64" ;;
  armv7l|armv8l) FB_ARCH="armv7" ;;
  i686|i386)     FB_ARCH="386" ;;
  *) die "Unsupported CPU architecture '$ARCH' for the File Browser binary. See README for manual installation options." ;;
esac

say "Detected Termux architecture: $ARCH"
say "Updating Termux packages"
pkg update -y
pkg upgrade -y

say "Installing required utilities"
pkg install -y openssh termux-auth procps termux-tools curl wget jq tar gzip aria2 python

say "Requesting Android shared-storage permission"
termux-setup-storage || true
mkdir -p "$HOME/bin" "$HOME/.termux/boot" "$HOME/.config/termux-media-server" "$FB_DIR" "$LOG_DIR" "$PREFIX/bin"

# Use repository files when running from a Git clone; otherwise fetch the
# current companion scripts. A single-file one-command install works without login.
install_repo_file() {
  local repo_path="$1"
  local destination="$2"
  local mode="${3:-755}"
  if [[ -e "$SCRIPT_DIR/.git" && -f "$SCRIPT_DIR/$repo_path" ]]; then
    install -m "$mode" "$SCRIPT_DIR/$repo_path" "$destination"
  else
    curl -fsSL "$RAW_BASE/$repo_path" -o "$destination"
    chmod "$mode" "$destination"
  fi
}

say "Installing service, boot, status, legacy-Jellyfin, and download scripts"
install_repo_file "start-media.sh" "$START_SCRIPT" 700
install_repo_file "boot-start-media.sh" "$BOOT_SCRIPT" 700
install_repo_file "media-status.sh" "$PREFIX/bin/media-status" 755
install_repo_file "start-legacy-jellyfin.sh" "$HOME/bin/start-legacy-jellyfin.sh" 700
install_repo_file "setup-legacy-jellyfin.sh" "$HOME/bin/setup-legacy-jellyfin.sh" 700
install_repo_file "download.sh" "$PREFIX/bin/dl" 755

# Ask only once whether password-based SSH is already configured. This avoids
# overwriting an existing password when an installation is rerun.
if [[ ! -f "$SSH_SETUP_MARKER" ]]; then
  echo
  echo "SSH password setup"
  echo "If you already ran 'passwd' and can log in over SSH, answer yes."
  printf "Have you already set your SSH password? [y/N]: "
  IFS= read -r ssh_password_ready || ssh_password_ready=""
  case "$ssh_password_ready" in
    [Yy]|[Yy][Ee][Ss])
      say "Keeping the existing SSH password"
      ;;
    *)
      command -v passwd >/dev/null 2>&1 || die "The passwd command is unavailable. Run 'pkg install termux-auth', then 'passwd', then rerun this setup."
      passwd
      ;;
  esac
  touch "$SSH_SETUP_MARKER"
fi

say "Installing Jellyfin (optional)"
TERMUX_ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
JELLYFIN_STATUS="not installed"
IS_ARM32_TERMUX=0

# The official Termux Jellyfin server package excludes 32-bit ARM.
if [[ "$TERMUX_ARCH" == "arm" || "$TERMUX_ARCH" == "armhf" || "$TERMUX_ARCH" == "armv7" || "$TERMUX_ARCH" == "armv7l" ]]; then
  IS_ARM32_TERMUX=1
  warn "Native Jellyfin is not available for 32-bit ARM. An optional Jellyfin 10.10.7 Debian/PRoot installer is available."
  JELLYFIN_STATUS="not installed (32-bit ARM)"
elif pkg install -y jellyfin-server jellyfin-ffmpeg; then
  JELLYFIN_STATUS="installed (native Termux)"
else
  warn "Jellyfin packages could not be found or installed for architecture '$TERMUX_ARCH'. Continuing with other services."
  JELLYFIN_STATUS="unavailable for this Termux setup"
fi

say "Installing File Browser"
if ! command -v filebrowser >/dev/null 2>&1; then
  api_json="$(mktemp)"
  tmpdir="$(mktemp -d)"
  trap 'rm -f "${api_json:-}"; rm -rf "${tmpdir:-}"' EXIT
  curl -fsSL https://api.github.com/repos/filebrowser/filebrowser/releases/latest -o "$api_json"
  asset_url="$(jq -r --arg arch "$FB_ARCH" '.assets[] | select(.name | test("linux-" + $arch + "-filebrowser\\.tar\\.gz$")) | .browser_download_url' "$api_json" | head -n 1)"
  [[ -n "$asset_url" && "$asset_url" != "null" ]] || die "Could not find File Browser release asset for architecture '$FB_ARCH'."
  curl -fL "$asset_url" -o "$tmpdir/filebrowser.tar.gz"
  tar -xzf "$tmpdir/filebrowser.tar.gz" -C "$tmpdir"
  [[ -f "$tmpdir/filebrowser" ]] || die "File Browser archive did not contain the expected binary."
  install -m 755 "$tmpdir/filebrowser" "$PREFIX/bin/filebrowser"
  rm -f "$api_json"
  rm -rf "$tmpdir"
  trap - EXIT
else
  say "File Browser already installed; keeping existing binary"
fi

say "Configuring File Browser"
mkdir -p "$FB_DIR"
if [[ ! -f "$FB_DB" ]]; then
  filebrowser config init -d "$FB_DB"
  echo "Create a strong password for the File Browser admin account."
  while true; do
    read -r -s -p "New File Browser admin password: " fb_pass; printf '\n'
    read -r -s -p "Confirm password: " fb_pass2; printf '\n'
    [[ -n "$fb_pass" ]] || { echo "Password cannot be empty."; continue; }
    [[ "$fb_pass" == "$fb_pass2" ]] || { echo "Passwords did not match. Try again."; continue; }
    break
  done
  filebrowser users add admin "$fb_pass" --perm.admin -d "$FB_DB"
  unset fb_pass fb_pass2
else
  say "Existing File Browser database found; preserving existing users and password"
fi

# Offer an explicitly opted-in legacy Jellyfin install only on 32-bit ARM.
# It installs an older server inside Debian/PRoot and uses extra storage.
if [[ "$IS_ARM32_TERMUX" == "1" ]]; then
  if [[ -f "$HOME/.config/termux-media-server/legacy-jellyfin-enabled" ]]; then
    JELLYFIN_STATUS="legacy Jellyfin 10.10.7 enabled"
    say "Legacy Jellyfin already configured; keeping its installation"
  else
    echo
    echo "Legacy Jellyfin for 32-bit ARM"
    echo "This installs Jellyfin 10.10.7 inside Debian/PRoot and uses extra storage."
    echo "It is an older release; keep access on your local network or Tailscale."
    printf "Install legacy Jellyfin now? [y/N]: "
    IFS= read -r legacy_jellyfin_choice || legacy_jellyfin_choice=""
    case "$legacy_jellyfin_choice" in
      [Yy]|[Yy][Ee][Ss])
        if bash "$HOME/bin/setup-legacy-jellyfin.sh"; then
          JELLYFIN_STATUS="legacy Jellyfin 10.10.7 (Debian/PRoot)"
        else
          warn "Legacy Jellyfin setup did not complete. The other media services can still be used."
          JELLYFIN_STATUS="legacy Jellyfin setup failed (see errors above)"
        fi
        ;;
      *)
        say "Skipping legacy Jellyfin. You can install it later with: bash ~/bin/setup-legacy-jellyfin.sh"
        ;;
    esac
  fi
fi

chmod 700 "$START_SCRIPT" "$BOOT_SCRIPT" "$HOME/bin/start-legacy-jellyfin.sh" "$HOME/bin/setup-legacy-jellyfin.sh"
chmod 755 "$PREFIX/bin/dl" "$PREFIX/bin/media-status"

# Start services whenever a Termux shell opens. Avoid duplicate hook lines.
touch "$BASHRC"
HOOK='bash "$HOME/bin/start-media.sh"'
if ! grep -Fqx "$HOOK" "$BASHRC"; then
  printf '\n# Start media-server services when a Termux shell opens\n%s\n' "$HOOK" >> "$BASHRC"
fi

say "Starting services now"
bash "$START_SCRIPT"

cat <<SUMMARY

SETUP COMPLETE
==============
Termux username:       $(id -un)
SSH port:              8022
File Browser:          http://127.0.0.1:8080
Jellyfin status:       $JELLYFIN_STATUS
Jellyfin URL (if installed): http://127.0.0.1:8096
aria2:                 $(command -v aria2c || echo unavailable)
Download command:      dl
Status command:        media-status
Startup command:       bash ~/bin/start-media.sh
Log directory:         $LOG_DIR

ONE-TIME FINAL STEPS
1. If you want startup after a reboot, install Termux:Boot from the same trusted source as Termux and open Termux:Boot once.
   A boot hook has already been installed at: $BOOT_SCRIPT
2. In Android Settings, set Termux and Termux:Boot battery usage to Unrestricted / Don't optimize where available.
3. Set up Tailscale separately if you need remote access from outside your local network.
4. Complete Jellyfin's first-run setup only if Jellyfin was installed and is available on this device.

The installer sets up shell startup and a Termux:Boot hook, but Android may still terminate background processes.
Existing File Browser users/database and Jellyfin data are preserved.
SUMMARY
