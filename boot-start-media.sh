#!/data/data/com.termux/files/usr/bin/bash
# Termux:Boot hook: start the media server after Android boots.
# Install/open the Termux:Boot Android app once for this hook to run at boot.
set -u

HOME="${HOME:-/data/data/com.termux/files/home}"
LOG_DIR="$HOME/.local/share/media-server-logs"
mkdir -p "$LOG_DIR"

# Give Android networking and storage a moment to initialize.
sleep 10

if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock >> "$LOG_DIR/boot.log" 2>&1 || true
fi

bash "$HOME/bin/start-media.sh" >> "$LOG_DIR/boot.log" 2>&1
