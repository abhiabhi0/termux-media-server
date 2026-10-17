# Termux Media Server

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-green.svg)](https://termux.dev/)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Shell syntax](https://github.com/abhiabhi0/termux-media-server/actions/workflows/shell-syntax.yml/badge.svg)](https://github.com/abhiabhi0/termux-media-server/actions/workflows/shell-syntax.yml)

A self-hosted media and file server setup for Android using Termux. It brings together Jellyfin for media streaming, File Browser for web-based file management, SSH for remote administration, and aria2 for downloads. Connect from Windows or other devices over your private Tailscale network.

The project provides setup automation, standalone service startup, and a plain-text quick reference. Compatibility depends on your device architecture and available Termux packages; review the requirements and limitations before installing.

## Features

- **Jellyfin:** Stream your media through a web browser or compatible client.
- **Legacy Jellyfin for 32-bit ARM:** Optionally run Jellyfin 10.10.7 inside Debian/PRoot when native Termux packages are unavailable.
- **File Browser:** Browse, upload, download, and manage files through a web interface.
- **SSH:** Remotely access the phone's Termux shell from Windows.
- **aria2:** Download files using HTTP/HTTPS URLs, magnet links, and `.torrent` files.
- **Tailscale:** Securely connect your phone and PC without exposing services directly to the public internet.
- **Persistent configuration:** Preserve existing Jellyfin data and File Browser accounts when rerunning the setup script.
- **Background services:** Start services when a Termux shell opens.

## Requirements

- An Android phone that supports Termux.
- Termux installed from a trusted source, such as [F-Droid](https://f-droid.org/packages/com.termux/) or the official [Termux GitHub repository](https://github.com/termux/termux-app).
- A Windows PC with [Tailscale](https://tailscale.com/download) installed.
- An internet connection for installation and downloads.
- Sufficient free storage for your media and downloads.

Jellyfin package availability and performance depend on your Android architecture, Android version, and configured Termux repositories.

## Installation

### One-command installation (no GitHub login required)

1. Install Termux from a trusted source, such as [F-Droid](https://f-droid.org/packages/com.termux/) or the official [Termux GitHub repository](https://github.com/termux/termux-app).
2. Open Termux and paste this single line:

```bash
curl -fsSL https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main/setup-media-server.sh -o "$HOME/setup-media-server.sh" && bash "$HOME/setup-media-server.sh"
```

The repository is public, so you do **not** need to sign in to GitHub or create a GitHub account. The command downloads the installer into your Termux home directory and runs it.

The installer configures the following in one run:

- Required Termux packages, including OpenSSH, password tools, process checks, and aria2.
- File Browser and its admin account (only asks for a password when creating a new database; existing account/database are preserved).
- The `dl` download shortcut and `media-status` service checker.
- The managed service script at `~/bin/start-media.sh`.
- A duplicate-checked `.bashrc` hook that starts services when a Termux shell opens.
- A Termux:Boot hook at `~/.termux/boot/00-start-media-server` for startup after a device reboot.

During setup, Android may show a storage-permission prompt. The installer asks whether you have already set the Termux SSH password. Answer **yes** if you previously ran `passwd` and SSH login works; otherwise answer **no** to set it. This prompt is remembered so a rerun does not repeatedly ask. Keep your SSH and File Browser passwords private.

### Enable automatic startup after reboot

The setup script prepares the boot hook, but Android does not let a shell script silently install another Android app. To finish boot-time startup once:

1. Install the [Termux:Boot app](https://github.com/termux/termux-boot) from the **same source/signing channel** as your Termux app.
2. Open Termux:Boot once after installing it.
3. Set battery usage for Termux and Termux:Boot to **Unrestricted** or **Don't optimize** in Android settings, where available.

After that, Termux:Boot runs the prepared hook after Android reboots. It waits briefly for the phone to initialize, then starts the services. The regular `.bashrc` hook also starts services when you open a Termux shell. Android can still terminate background processes, so this improves reliability but does not guarantee that services run forever.

Use `media-status` at any time to check SSH, Jellyfin, File Browser, active aria2 downloads, and local web endpoints. Use `bash ~/bin/start-media.sh` to start/recover services manually if needed.

Tailscale is separate and is not installed or signed in by this script. Install it on the phone and client devices when you need private remote access.

**Compatibility note:** The official Termux Jellyfin server package is unavailable for 32-bit ARM. On that architecture, the main installer offers an optional legacy setup using Jellyfin 10.10.7 inside Debian Bookworm (`armhf`) under PRoot. This older release is a compatibility workaround, not the recommended route for supported 64-bit devices. It consumes additional storage and should only be accessed on your local network or through Tailscale; do not expose it directly to the public internet.

### Legacy Jellyfin for 32-bit ARM Termux

Use this route when Termux reports `arm` from `dpkg --print-architecture` and the native Jellyfin package is unavailable. The setup targets Debian Bookworm `armhf` and Jellyfin `10.10.7+deb12`.

For a fresh installation, the main installer offers this as an opt-in step on 32-bit ARM devices. To add it to an existing Termux Media Server installation, run:

```bash
curl -fsSL https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main/setup-legacy-jellyfin.sh -o "$HOME/setup-legacy-jellyfin.sh" && bash "$HOME/setup-legacy-jellyfin.sh"
```

The script:

1. Installs `proot-distro` and Termux FFmpeg.
2. Creates a Debian Bookworm `armhf` container if one is not already installed. It will not replace a container that reports a different architecture.
3. Configures the official Jellyfin APT repository and installs Jellyfin server and web interface version 10.10.7.
4. Uses Termux's FFmpeg from inside PRoot and explicitly points Jellyfin to `/usr/share/jellyfin/web`. The packaged Debian FFmpeg may fail to load on Android/PRoot because of executable-stack restrictions.
5. Installs `~/bin/start-legacy-jellyfin.sh`, enables the legacy server marker, refreshes the managed service/status/boot scripts, and starts Jellyfin in the background.

The existing `~/.bashrc` hook and Termux:Boot hook call `start-media.sh`; once legacy Jellyfin is enabled, that script launches it in the background when a Termux shell opens and after a reboot via Termux:Boot.

Useful commands:

```bash
bash ~/bin/start-legacy-jellyfin.sh
bash ~/bin/start-media.sh
media-status
tail -f ~/.local/share/media-server-logs/jellyfin-legacy.log
tail -f ~/.local/share/media-server-logs/jellyfin-launcher.log
```

If `proot-distro install` printed a Python `py3compile` traceback but `proot-distro list` works afterward, check the command's actual result instead of assuming the container installation failed. The expected architecture check is `proot-distro login debian -- dpkg --print-architecture`, which should print `armhf`.

Jellyfin 10.10.7 is an older release. Keep it on your local network or private Tailscale network, use a strong Jellyfin account password, and do not expose port 8096 directly to the public internet.

## Configure remote access

### 1. Install Tailscale

Install the official Tailscale application on both Android and Windows. Sign in to the same Tailscale account on both devices.

This setup script does not install Tailscale or change your DNS settings.

### 2. Find your phone's Tailscale address

Open the Tailscale app and find your phone's Tailscale IP address or MagicDNS hostname.

Use the values for your own devices in the examples below.

### 3. Access the services

Replace `YOUR_PHONE_TAILSCALE_NAME` with your phone's Tailscale IP address or MagicDNS hostname.

| Service | Address |
|---|---|
| Jellyfin | `http://YOUR_PHONE_TAILSCALE_NAME:8096` |
| File Browser | `http://YOUR_PHONE_TAILSCALE_NAME:8080` |
| SSH | Port `8022` |

Complete Jellyfin's first-run setup in your browser if you have not done so already.

Keep File Browser authentication enabled. Use Tailscale for remote access rather than exposing these ports directly to the public internet.

## Connect from Windows using SSH

Open PowerShell on Windows and run:

```powershell
ssh -p 8022 YOUR_TERMUX_USERNAME@YOUR_PHONE_TAILSCALE_NAME
```

Replace the username with the value returned by this command in Termux:

```bash
whoami
```

If you have not set a Termux password for SSH yet, run this once in Termux and follow the prompts:

```bash
passwd
```

The installer asks about this during first setup and runs `passwd` only if you say you have not already configured an SSH password. The SSH server is started by `start-media.sh`; you normally do not need to start it manually. To check it and the other services, run:

```bash
media-status
```

If a service needs to be recovered, run `bash ~/bin/start-media.sh`.

Replace the hostname with your phone's Tailscale IP or MagicDNS hostname. If the client is on the same local network and does not have Tailscale installed, use the phone's local Wi-Fi IP instead.

Once connected, commands run on the Android phone, not on Windows.

## Simple downloads with `dl`

The setup script installs a small `dl` command backed by aria2. You do not need to remember aria2 options.

If you've already set up the server before this helper was added, install it once with:

```bash
curl -fsSL https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main/download.sh -o "$PREFIX/bin/dl"
chmod 755 "$PREFIX/bin/dl"
```

### Recommended: paste a link when prompted

In Termux or an SSH session connected to the phone, run:

```bash
dl
```

Paste one of these at the prompt and press Enter:

- A direct HTTP/HTTPS download URL.
- A magnet link.
- A path to a local `.torrent` file.
- A URL pointing to a remote `.torrent` file.

Downloads are saved to `~/storage/shared/Download`, and aria2 displays progress in the terminal.

### Or provide the link directly

```bash
dl "https://example.com/file.zip"
dl "magnet:?xt=urn:btih:..."
dl "https://example.com/file.torrent"
dl "~/storage/shared/Download/file.torrent"
```

**Important:** Quote magnet links when passing them as command arguments because they commonly contain `&` characters. The prompt mode (`dl` with no arguments) avoids this issue.

For a remote `.torrent` URL, aria2 automatically parses the torrent and starts downloading its contents when the URL ends in `.torrent` or the server responds with the BitTorrent content type. The helper uses aria2's `--follow-torrent=mem` option, so it does not leave a separate torrent metadata file in the download directory when processing such a URL. If a site hides the torrent behind a webpage or returns an unexpected content type, use a direct torrent-file URL instead.

For BitTorrent downloads, the helper stops seeding after completion. Speed depends on peer availability and network connectivity. Only download content you have permission to access.

Check downloads and active processes:

```bash
ls -lh ~/storage/shared/Download
pgrep -af aria2c
```

## Start and check services

Start or recover the configured services:

```bash
bash ~/bin/start-media.sh
```

Check all services and local web endpoints in one command:

```bash
media-status
```

The repository also includes the standalone [`start-media.sh`](start-media.sh) startup script. The setup installer creates a copy at `~/bin/start-media.sh`. If you need to install or refresh it manually, run this in Termux:

```bash
mkdir -p ~/bin
curl -fsSL https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main/start-media.sh -o ~/bin/start-media.sh
chmod 700 ~/bin/start-media.sh
bash ~/bin/start-media.sh
```

The plain-text [`QUICK_COMMANDS.txt`](QUICK_COMMANDS.txt) file contains common startup, status-checking, download, log, and Tailscale commands. To copy it onto the phone and view it in Termux:

```bash
mkdir -p ~/notes
curl -fsSL https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main/QUICK_COMMANDS.txt -o ~/notes/QUICK_COMMANDS.txt
cat ~/notes/QUICK_COMMANDS.txt
```

Check the running processes:

```bash
pgrep -af jellyfin
pgrep -af filebrowser
pgrep -af sshd
```

For legacy ARM32 Jellyfin, use `media-status` and the `jellyfin-legacy.log` log, since the server runs inside PRoot rather than as a native Termux package.

Check Jellyfin locally:

```bash
curl -I http://127.0.0.1:8096
```

Check File Browser locally:

```bash
curl -I http://127.0.0.1:8080
```

Follow the service logs:

```bash
tail -f ~/.local/share/media-server-logs/jellyfin.log
tail -f ~/.local/share/media-server-logs/jellyfin-legacy.log
tail -f ~/.local/share/media-server-logs/jellyfin-launcher.log
tail -f ~/.local/share/media-server-logs/filebrowser.log
```

The SSH server normally listens on port `8022` in Termux.

## Android background reliability

Android may suspend or terminate background processes to save battery.

For better reliability:

1. Set Termux battery usage to **Unrestricted** or disable battery optimization for Termux, where available.
2. Keep sufficient free storage available.
3. Use `termux-wake-lock` when you need the CPU to stay awake during long-running tasks.
4. Keep the phone plugged in during extended media streaming or large downloads.

These steps improve reliability but do not guarantee that Android will keep every process running indefinitely.

The setup script installs a boot hook in `~/.termux/boot/00-start-media-server`. To enable it, install and open the Termux:Boot companion app once (from the same source/signing channel as Termux). Set battery use for Termux and Termux:Boot to Unrestricted where available. The hook starts services after reboot, while the `.bashrc` hook starts them when a Termux shell opens. Android can still kill background apps, so no setup can guarantee that services run forever.

## Security and privacy

- Use a strong, unique File Browser administrator password.
- Never commit passwords, private keys, Tailscale credentials, databases, or personal logs to GitHub.
- Prefer Tailscale for remote access.
- Do not expose SSH, File Browser, or Jellyfin directly to the public internet without appropriate security controls.
- Download and share only content you have permission to access.

## Limitations

- Jellyfin availability depends on Termux repository and device compatibility.
- BitTorrent download speed depends on peers, network connectivity, and tracker or DHT availability.
- Some direct-download websites require authentication or do not support aria2.
- Android storage permissions and background restrictions can affect downloads and services.
- This project does not configure Tailscale, change DNS settings, or guarantee boot-time startup.

## Troubleshooting

### SSH connection fails

- Confirm that Tailscale is connected on both devices.
- Confirm that Termux is running and the SSH server is started.
- Check that you are using the correct Termux username and phone address.
- Use the phone's Tailscale IP if its MagicDNS hostname does not resolve.

### Jellyfin or File Browser does not open

- Check whether the relevant endpoint responds with `media-status`.
- Start services with `bash ~/bin/start-media.sh`.
- For legacy Jellyfin, check `tail -n 80 ~/.local/share/media-server-logs/jellyfin-legacy.log` and `tail -n 80 ~/.local/share/media-server-logs/jellyfin-launcher.log`.
- Verify the port and phone's current Tailscale address. The legacy server uses port `8096`.

### aria2 does not download

- Check whether the URL is a direct download link.
- Confirm that the phone has internet access and sufficient storage.
- For BitTorrent, check whether peers are available and the network permits peer connections.
- Inspect `~/aria2-download.log` for error messages.

## Contributing

Contributions are welcome, including bug reports, documentation improvements, compatibility fixes, and tested enhancements.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening an issue or pull request. For significant changes, open an issue first to discuss the approach. Never commit passwords, tokens, private keys, personal logs, or runtime databases.

## License

This project is licensed under the [MIT License](LICENSE). You may use, modify, and distribute the project under the terms of that license.