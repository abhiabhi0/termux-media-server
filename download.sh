#!/data/data/com.termux/files/usr/bin/bash
# Simple aria2 wrapper for Termux.
# Usage: dl [URL_OR_MAGNET_OR_TORRENT_PATH]
set -Eeuo pipefail

DOWNLOAD_DIR="${DOWNLOAD_DIR:-$HOME/storage/shared/Download}"

usage() {
  cat <<'USAGE'
Usage:
  dl
      Paste a direct URL, magnet link, or local .torrent path when prompted.

  dl "URL_OR_MAGNET"
      Start a download directly.

Downloads are saved to:
  ~/storage/shared/Download

Examples:
  dl "https://example.com/file.zip"
  dl "magnet:?xt=urn:btih:..."
  dl "~/storage/shared/Download/file.torrent"

For magnet links with '&' characters, wrap the link in quotes when passing it as an argument.
USAGE
}

if ! command -v aria2c >/dev/null 2>&1; then
  echo "Error: aria2c is not installed. Run: pkg install aria2" >&2
  exit 127
fi

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
elif [[ $# -eq 1 ]]; then
  INPUT="$1"
else
  printf 'Paste a direct URL, magnet link, or local .torrent path: '
  IFS= read -r INPUT || true
fi

INPUT="${INPUT#"${INPUT%%[![:space:]]*}"}"
INPUT="${INPUT%"${INPUT##*[![:space:]]}"}"

if [[ -z "$INPUT" ]]; then
  echo "Error: no URL or torrent path was provided." >&2
  exit 2
fi

# Expand a leading ~/ when a local torrent path is entered at the prompt.
if [[ "$INPUT" == "~/"* ]]; then
  INPUT="$HOME/${INPUT#~/}"
fi

mkdir -p "$DOWNLOAD_DIR"

# aria2 recognizes remote .torrent files by URL suffix or BitTorrent content type.
# follow-torrent=mem parses remote torrent metadata without leaving a separate .torrent file.
COMMON_OPTIONS=(
  --dir="$DOWNLOAD_DIR"
  --continue=true
  --max-connection-per-server=8
  --split=8
  --seed-time=0
)

case "$INPUT" in
  magnet:*)
    echo "Starting magnet download..."
    aria2c "${COMMON_OPTIONS[@]}" "$INPUT"
    ;;
  http://*|https://*|ftp://*|sftp://*)
    echo "Starting URL download (torrent URLs will be processed as torrents when recognized)..."
    aria2c "${COMMON_OPTIONS[@]}" --follow-torrent=mem "$INPUT"
    ;;
  *)
    if [[ -f "$INPUT" && "${INPUT,,}" == *.torrent ]]; then
      echo "Starting download from local torrent file..."
      aria2c --dir="$DOWNLOAD_DIR" --seed-time=0 "$INPUT"
    elif [[ -f "$INPUT" ]]; then
      echo "Error: local file is not a .torrent file: $INPUT" >&2
      exit 2
    else
      echo "Error: enter an HTTP(S), FTP, SFTP URL, a magnet link, or an existing .torrent file." >&2
      exit 2
    fi
    ;;
esac
