#!/data/data/com.termux/files/usr/bin/bash
# Show media-server process and local HTTP status.
set -u

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"

check_process() {
  local label="$1"
  local pattern="$2"
  if pgrep -f "$pattern" >/dev/null 2>&1; then
    printf '%-14s RUNNING\n' "$label"
  else
    printf '%-14s NOT RUNNING\n' "$label"
  fi
}

check_http() {
  local label="$1"
  local url="$2"
  local result
  result="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 4 "$url" 2>/dev/null || true)"
  if [[ -n "$result" && "$result" != "000" ]]; then
    printf '%-14s HTTP %s\n' "$label" "$result"
  else
    printf '%-14s NO RESPONSE\n' "$label"
  fi
}

echo "=== Service processes ==="
check_process "SSH" '[s]shd'
check_process "Jellyfin" '[j]ellyfin'
check_process "File Browser" '[f]ilebrowser'
if pgrep -x aria2c >/dev/null 2>&1; then
  printf '%-14s RUNNING (download active)\n' "aria2"
else
  printf '%-14s IDLE (normal when not downloading)\n' "aria2"
fi

echo
echo "=== Local web endpoints ==="
check_http "Jellyfin" "http://127.0.0.1:8096/"
check_http "File Browser" "http://127.0.0.1:8080/"

echo
echo "=== Commands ==="
command -v dl >/dev/null 2>&1 && echo "dl             AVAILABLE" || echo "dl             NOT INSTALLED"
echo "Logs: $HOME/.local/share/media-server-logs/"
