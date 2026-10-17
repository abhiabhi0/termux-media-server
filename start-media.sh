#!/data/data/com.termux/files/usr/bin/bash
# Start media-server services in Termux.
# Usage: bash ~/bin/start-media.sh
set -u

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
LOG_DIR="$HOME/.local/share/media-server-logs"
FB_DB="$HOME/.config/filebrowser/filebrowser.db"
mkdir -p "$LOG_DIR"

# Jellyfin's .NET runtime path in Termux package builds.
export DOTNET_ROOT="$PREFIX/lib/dotnet"
export DOTNET_ROOT_ARM64="$PREFIX/lib/dotnet"

# Keep the CPU awake while Termux is active when the helper is available.
# Android may still terminate background processes.
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock >/dev/null 2>&1 || true
fi

# SSH server. Generate host keys only when none exist.
if command -v sshd >/dev/null 2>&1; then
  if ! find "$PREFIX/etc/ssh" -maxdepth 1 -type f -name 'ssh_host_*_key' -print -quit 2>/dev/null | grep -q .; then
    if command -v ssh-keygen >/dev/null 2>&1; then
      ssh-keygen -A >> "$LOG_DIR/sshd.log" 2>&1 || true
    fi
  fi
  if ! pgrep -x sshd >/dev/null 2>&1; then
    sshd 2>> "$LOG_DIR/sshd.log" || echo "WARNING: sshd did not start; see $LOG_DIR/sshd.log" >&2
  fi
else
  echo "WARNING: OpenSSH is not installed; run pkg install openssh." >&2
fi

# Prefer the native Termux package. On unsupported 32-bit ARM devices, the
# optional Debian/PRoot legacy installer sets a marker and installs a separate launcher.
if command -v jellyfin >/dev/null 2>&1; then
  if ! pgrep -f '[j]ellyfin' >/dev/null 2>&1; then
    nohup jellyfin >> "$LOG_DIR/jellyfin.log" 2>&1 < /dev/null &
  fi
elif [[ -f "$HOME/.config/termux-media-server/legacy-jellyfin-enabled" && -x "$HOME/bin/start-legacy-jellyfin.sh" ]]; then
  if ! curl -fsS --max-time 3 http://127.0.0.1:8096/ -o /dev/null >/dev/null 2>&1; then
    nohup "$HOME/bin/start-legacy-jellyfin.sh" >> "$LOG_DIR/jellyfin-launcher.log" 2>&1 < /dev/null &
  fi
else
  echo "INFO: Native Jellyfin is not installed and legacy ARM32 Jellyfin is not enabled."
fi

# File Browser requires its existing database; do not reset or recreate it here.
if command -v filebrowser >/dev/null 2>&1 && [[ -f "$FB_DB" ]]; then
  if ! pgrep -f '[f]ilebrowser --address 0.0.0.0 --port 8080' >/dev/null 2>&1; then
    nohup filebrowser --address 0.0.0.0 --port 8080 \
      --root "$HOME/storage/shared" \
      -d "$FB_DB" >> "$LOG_DIR/filebrowser.log" 2>&1 < /dev/null &
  fi
elif ! command -v filebrowser >/dev/null 2>&1; then
  echo "WARNING: File Browser is not installed."
elif [[ ! -f "$FB_DB" ]]; then
  echo "WARNING: File Browser database not found at $FB_DB; keeping existing files untouched." >&2
fi

sleep 2

echo "Media server startup check complete."
if pgrep -x sshd >/dev/null 2>&1; then echo "SSH: RUNNING (port 8022 by default)"; else echo "SSH: NOT RUNNING"; fi
if command -v jellyfin >/dev/null 2>&1; then
  if pgrep -f '[j]ellyfin' >/dev/null 2>&1; then echo "Jellyfin: RUNNING (native Termux)"; else echo "Jellyfin: INSTALLED, PROCESS NOT DETECTED"; fi
elif [[ -f "$HOME/.config/termux-media-server/legacy-jellyfin-enabled" ]]; then
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:8096/ 2>/dev/null || true)"
  case "$code" in
    2??|3??) echo "Jellyfin: RUNNING (legacy Debian/PRoot, HTTP $code)" ;;
    *) echo "Jellyfin: LEGACY ENABLED, NOT RESPONDING (see jellyfin-legacy.log)" ;;
  esac
else
  echo "Jellyfin: NOT INSTALLED"
fi
if pgrep -f '[f]ilebrowser --address 0.0.0.0 --port 8080' >/dev/null 2>&1; then echo "File Browser: RUNNING"; else echo "File Browser: NOT RUNNING"; fi
echo "Check full status with: media-status"
echo "Logs: $LOG_DIR"
