#!/data/data/com.termux/files/usr/bin/bash
# Android + Termux Media Server setup
# Usage: bash setup-media-server.sh
# Designed for Termux on Android. Package availability depends on CPU architecture/repository.
set -Eeuo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
FB_DIR="$HOME/.config/filebrowser"
FB_DB="$FB_DIR/filebrowser.db"
LOG_DIR="$HOME/.local/share/media-server-logs"
START_SCRIPT="$HOME/bin/start-media.sh"
BASHRC="$HOME/.bashrc"

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

say "Installing common utilities"
pkg install -y openssh curl wget jq tar gzip aria2 python

say "Requesting Android shared-storage permission"
termux-setup-storage || true
mkdir -p "$HOME/bin" "$FB_DIR" "$LOG_DIR"

say "Installing the simple aria2 download command (dl)"
if [[ -f "$SCRIPT_DIR/download.sh" ]]; then
  install -m 755 "$SCRIPT_DIR/download.sh" "$PREFIX/bin/dl"
else
  curl -fsSL https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main/download.sh -o "$PREFIX/bin/dl"
  chmod 755 "$PREFIX/bin/dl"
fi

say "Installing Jellyfin"
if ! pkg install -y jellyfin-server jellyfin-ffmpeg; then
  die "Jellyfin packages were not available for this Termux installation/repository. See README: Jellyfin support varies by architecture and Termux repository."
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

say "Creating service startup script"
cat > "$START_SCRIPT" <<'START_EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -u
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
LOG_DIR="$HOME/.local/share/media-server-logs"
FB_DB="$HOME/.config/filebrowser/filebrowser.db"
mkdir -p "$LOG_DIR"

# Jellyfin's .NET runtime path in Termux package builds.
export DOTNET_ROOT="$PREFIX/lib/dotnet"
export DOTNET_ROOT_ARM64="$PREFIX/lib/dotnet"

# Helpful but not a guarantee against Android background process killing.
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock >/dev/null 2>&1 || true
fi

if ! pgrep -x sshd >/dev/null 2>&1; then
  sshd
fi

if ! pgrep -x jellyfin >/dev/null 2>&1; then
  nohup jellyfin >> "$LOG_DIR/jellyfin.log" 2>&1 < /dev/null &
fi

if command -v filebrowser >/dev/null 2>&1 && [[ -f "$FB_DB" ]]; then
  if ! pgrep -f '[f]ilebrowser --address 0.0.0.0 --port 8080' >/dev/null 2>&1; then
    nohup filebrowser --address 0.0.0.0 --port 8080 \
      --root "$HOME/storage/shared" \
      -d "$FB_DB" >> "$LOG_DIR/filebrowser.log" 2>&1 < /dev/null &
  fi
fi
START_EOF
chmod 700 "$START_SCRIPT"

touch "$BASHRC"
HOOK='bash "$HOME/bin/start-media.sh"'
if ! grep -Fqx "$HOOK" "$BASHRC"; then
  printf '\n# Start media-server services when a Termux shell opens\n%s\n' "$HOOK" >> "$BASHRC"
fi

say "Starting services"
bash "$START_SCRIPT"
sleep 2

cat <<SUMMARY

SETUP COMPLETE
==============
Termux username:       $(id -un)
Shared storage:        $HOME/storage/shared
Download folder:       $HOME/storage/shared/Download
Jellyfin:              http://127.0.0.1:8096
File Browser:          http://127.0.0.1:8080
SSH port:              8022
aria2:                 $(command -v aria2c || echo unavailable)
Download shortcut:     $(command -v dl || echo "$PREFIX/bin/dl")
Logs:                  $LOG_DIR

Download usage:
- Run: dl
- Paste a direct URL, magnet link, local .torrent path, or remote .torrent URL.
- Downloads go to: $HOME/storage/shared/Download

Next:
- Install Tailscale separately on Android and Windows; sign in to the same tailnet.
- Find this phone's Tailscale IP/name in the Tailscale app/admin console.
- On Windows use the included windows-connect.ps1 or see README.
- Complete Jellyfin's initial setup in a browser if not already done.
- This script starts services when a Termux shell opens; it does not guarantee startup immediately after Android reboot.
- Existing Jellyfin/File Browser data is preserved. Back up important configuration before major changes.
SUMMARY
