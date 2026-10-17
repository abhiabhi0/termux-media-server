#!/data/data/com.termux/files/usr/bin/bash
# Start Jellyfin 10.10.7 in Debian/PRoot on 32-bit ARM Termux.
# The package is run as Debian's dedicated jellyfin user, with Termux FFmpeg.
set -Eeuo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
LOG_DIR="$HOME/.local/share/media-server-logs"
LOG_FILE="$LOG_DIR/jellyfin-legacy.log"
STATE_DIR="$HOME/.local/state/termux-media-server"
PID_FILE="$STATE_DIR/legacy-jellyfin.pid"
URL="http://127.0.0.1:8096/"

say() { printf '%s\n' "$*"; }
mkdir -p "$LOG_DIR" "$STATE_DIR"

http_code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "$URL" 2>/dev/null || true)"
case "$http_code" in
  2??|3??)
    say "Legacy Jellyfin is already responding at $URL"
    exit 0
    ;;
esac

command -v proot-distro >/dev/null 2>&1 || {
  say "ERROR: proot-distro is missing. Run: pkg install proot-distro"
  exit 1
}
command -v ffmpeg >/dev/null 2>&1 || {
  say "ERROR: Termux FFmpeg is missing. Run: pkg install ffmpeg"
  exit 1
}

debian_arch="$(proot-distro login debian -- dpkg --print-architecture 2>/dev/null || true)"
if [[ "$debian_arch" != "armhf" ]]; then
  say "ERROR: Debian container is missing or is not armhf (reported: ${debian_arch:-unknown})."
  say "Run setup-legacy-jellyfin.sh to install the expected Debian Bookworm armhf environment."
  exit 1
fi

# A live PID recorded by the previous launch means startup is already in progress.
if [[ -s "$PID_FILE" ]]; then
  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ "$old_pid" =~ ^[0-9]+$ ]] && kill -0 "$old_pid" 2>/dev/null; then
    say "Legacy Jellyfin is already starting (launcher PID $old_pid)."
    exit 0
  fi
  rm -f "$PID_FILE"
fi

# Confirm the Termux-built binary can execute with the prefix bind-mounted in PRoot.
if ! proot-distro login debian --bind "$PREFIX:/termux" -- /termux/bin/ffmpeg -version >/dev/null 2>&1; then
  say "ERROR: Termux FFmpeg could not run inside Debian/PRoot."
  say "Check that 'ffmpeg -version' works in Termux, then inspect $LOG_FILE."
  exit 1
fi

touch "$LOG_FILE"
printf '\n[%s] Starting Jellyfin 10.10.7 in Debian/PRoot\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"

# Keep the foreground Jellyfin process attached to the long-lived PRoot process.
nohup proot-distro login debian \
  --bind "$PREFIX:/termux" \
  -- su -p -s /bin/sh jellyfin -c \
  'cd /var/lib/jellyfin && exec /usr/bin/jellyfin --webdir=/usr/share/jellyfin/web --ffmpeg=/termux/bin/ffmpeg' \
  >> "$LOG_FILE" 2>&1 < /dev/null &

launcher_pid=$!
printf '%s\n' "$launcher_pid" > "$PID_FILE"

# Wait briefly for first startup, but don't kill a server that needs longer to initialize.
for _ in {1..30}; do
  sleep 2
  http_code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "$URL" 2>/dev/null || true)"
  case "$http_code" in
    2??|3??)
      say "Legacy Jellyfin is responding at $URL"
      exit 0
      ;;
  esac
  if ! kill -0 "$launcher_pid" 2>/dev/null; then
    rm -f "$PID_FILE"
    say "ERROR: Jellyfin exited before its web interface became available."
    say "Recent log output:"
    tail -n 50 "$LOG_FILE" || true
    exit 1
  fi
done

if kill -0 "$launcher_pid" 2>/dev/null; then
  say "Jellyfin is still starting. Check status with 'media-status' and logs at $LOG_FILE"
  exit 0
fi

rm -f "$PID_FILE"
say "ERROR: Jellyfin did not remain running. Recent log output:"
tail -n 50 "$LOG_FILE" || true
exit 1
