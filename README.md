# Termux Media Server

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-green.svg)](https://termux.dev/)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)

A self-hosted media and file server setup for Android using Termux. It brings together Jellyfin for media streaming, File Browser for web-based file management, SSH for remote administration, and aria2 for downloads. Connect from Windows or other devices over your private Tailscale network.

The project provides setup automation, standalone service startup, and a plain-text quick reference. Compatibility depends on your device architecture and available Termux packages; review the requirements and limitations before installing.

## Features

- **Jellyfin:** Stream your media through a web browser or compatible client.
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

The repository is public, so you do **not** need to sign in to GitHub or create a GitHub account. The command downloads the installer into your Termux home directory and runs it. It installs the required packages, requests Android shared-storage permission, installs the `dl` download shortcut, and configures Jellyfin, File Browser, and SSH where supported.

During setup, Android may show a storage-permission prompt. On a first-time File Browser setup, you will be prompted to create an administrator password. Keep it private.

The setup script can also be downloaded and reviewed before running it. It does not install or sign in to Tailscale; install the Tailscale app separately on the phone and other devices that need private remote access.

**Compatibility note:** Jellyfin package availability depends on your Android architecture and configured Termux repositories. If the package is unavailable for your device, setup will report an error rather than complete the Jellyfin installation.

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

Replace the hostname with your phone's Tailscale IP or MagicDNS hostname.

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

Start the configured services:

```bash
bash ~/bin/start-media.sh
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

The setup script's `.bashrc` hook starts services when a Termux shell opens. It does not guarantee automatic startup immediately after an Android reboot. Termux:Boot can be configured separately if automatic startup is required.

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

- Check whether the relevant process is running.
- Start services with `bash ~/bin/start-media.sh`.
- Verify the port and phone's current Tailscale address.
- Review the service logs for errors.

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