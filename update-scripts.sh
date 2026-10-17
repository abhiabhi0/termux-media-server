#!/data/data/com.termux/files/usr/bin/bash
# Safely refresh repository-managed Termux Media Server scripts without rerunning
# the full installer or upgrading Termux packages.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main/update-scripts.sh -o "$HOME/update-scripts.sh" && bash "$HOME/update-scripts.sh"
set -Eeuo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
RAW_BASE="https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main"

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required. Install it with: pkg install curl"
command -v bash >/dev/null 2>&1 || die "bash is required."
command -v install >/dev/null 2>&1 || die "The Termux 'install' utility is missing."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$HOME/bin" "$HOME/.termux/boot" "$PREFIX/bin"

backup_if_needed() {
  local destination="$1"
  local timestamp backup counter=0

  [[ -e "$destination" ]] || return 0
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup="${destination}.backup.${timestamp}"
  while [[ -e "$backup" ]]; do
    counter=$((counter + 1))
    backup="${destination}.backup.${timestamp}.${counter}"
  done
  cp -p "$destination" "$backup"
  say "Backed up existing file: $backup"
}

refresh_file() {
  local repo_path="$1"
  local destination="$2"
  local mode="$3"
  local is_bash="${4:-yes}"
  local downloaded="$TMP_DIR/${repo_path//\//_}"

  say "Checking $repo_path"
  curl -fsSL "$RAW_BASE/$repo_path" -o "$downloaded"

  if [[ "$is_bash" == "yes" ]]; then
    bash -n "$downloaded" || die "Bash syntax check failed for $repo_path; destination was not changed."
  fi

  if [[ -f "$destination" ]] && cmp -s "$downloaded" "$destination"; then
    say "Already up to date: $destination"
    return 0
  fi

  backup_if_needed "$destination"
  install -m "$mode" "$downloaded" "$destination"
  say "Installed: $destination"
}

# Update only scripts managed by this project. Existing changed files are backed
# up before replacement. Runtime databases, service data, credentials, and
# general Termux packages are intentionally not touched.
refresh_file "update-scripts.sh" "$HOME/bin/update-media-scripts.sh" 700
refresh_file "start-media.sh" "$HOME/bin/start-media.sh" 700
refresh_file "boot-start-media.sh" "$HOME/.termux/boot/00-start-media-server" 700
refresh_file "media-status.sh" "$PREFIX/bin/media-status" 755
refresh_file "start-legacy-jellyfin.sh" "$HOME/bin/start-legacy-jellyfin.sh" 700
refresh_file "setup-legacy-jellyfin.sh" "$HOME/bin/setup-legacy-jellyfin.sh" 700
refresh_file "download.sh" "$PREFIX/bin/dl" 755

say "Script refresh complete"
cat <<SUMMARY

No Termux package upgrade or Jellyfin/File Browser installation was run.
Runtime databases, service data, and passwords were not modified.
Existing differing managed scripts were backed up beside the original file.
The updater does not edit ~/.bashrc or restart services.

Run these manually only when you are ready:
  bash ~/bin/start-media.sh
  media-status
  dl
Future script refreshes:
  bash ~/bin/update-media-scripts.sh
SUMMARY
