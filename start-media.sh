#!/data/data/com.termux/files/usr/bin/bash
# Start media-server services in Termux.
# Usage: bash start-media.sh
set -u

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
LOG_DIR="$HOME/.local/share/media-server-logs"
FB_DB="$HOME/.config/filebrowser/filebrowser.db"

mkdir -p "$LOG_DIR"

# Jellyfin's .NET runtime path in supported Termux package builds.
export DOTNET_ROOT="$PREFIX/lib/dotnet"
export DOTNET_ROOT_ARM64="$PREFIX/lib/dotnet"

# Keep the CPU awake while Termux is active when the helper is available.
# Android may still terminate background processes.
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock >/dev/null 2>&1 || true
fi

# Start SSH if it is installed and not already running.
if command -v sshd >/dev/null 2>&1 && ! pgrep -x sshd >/dev/null 2>&1; then
  sshd
fi

# Start Jellyfin if it is installed and not already running.
if command -v jellyfin >/dev/null 2>&1 && ! pgrep -x jellyfin >/dev/null 2>&1; then
  nohup jellyfin >> "$LOG_DIR/jellyfin.log" 2>&1 < /dev/null &
fi

# Start File Browser only when its binary and existing database are available.
# The database contains its admin account; this script does not reset credentials.
if command -v filebrowser >/dev/null 2>&1 && [[ -f "$FB_DB" ]]; then
  if ! pgrep -f '[f]ilebrowser --address 0.0.0.0 --port 8080' >/dev/null 2>&1; then
    nohup filebrowser --address 0.0.0.0 --port 8080 \
      --root "$HOME/storage/shared" \
      -d "$FB_DB" >> "$LOG_DIR/filebrowser.log" 2>&1 < /dev/null &
  fi
fi

echo "Start checks submitted. Check processes with:"
echo "  pgrep -af sshd"
echo "  pgrep -af jellyfin"
echo "  pgrep -af filebrowser"
echo "Logs: $LOG_DIR"
