# Termux Media Server

A personal media and file server for Android using Termux. Access your files, stream media with Jellyfin, manage files through a browser, and download files remotely from a Windows PC.

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

### 1. Install Termux

Install and open Termux on your Android phone.

### 2. Run the setup script

Download `setup-media-server.sh` from this repository and place it in your phone's Download folder.

In Termux, run:

```bash
termux-setup-storage
cd ~/storage/shared/Download
bash setup-media-server.sh
```

Alternatively, if you placed the script in your Termux home directory:

```bash
bash ~/setup-media-server.sh
```

The script installs the required packages, configures the available services, and requests shared-storage access.

If File Browser is being configured for the first time, the script asks you to set an administrator password. Keep it private.

**Note:** If Jellyfin cannot be installed from your configured Termux repositories, check package availability and repository compatibility for your device.

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

## Download files using aria2

The setup script installs `aria2`, which provides the `aria2c` command.

All examples below save downloads into the phone's shared Download folder:

```bash
~/storage/shared/Download
```

Run the commands after connecting to the phone through SSH, or directly in Termux.

### 1. Download from a direct HTTP/HTTPS URL

```bash
aria2c -c -x 8 -s 8 \
  -d ~/storage/shared/Download \
  "DIRECT_DOWNLOAD_URL"
```

Replace `DIRECT_DOWNLOAD_URL` with a direct file-download URL.

- `-c` resumes supported interrupted downloads.
- `-x 8` allows up to eight connections per server.
- `-s 8` splits a download into up to eight segments.

A normal webpage URL is not necessarily a direct download link. Some websites require authentication, cookies, or other special handling.

### 2. Download using a magnet link

```bash
aria2c --seed-time=0 \
  -d ~/storage/shared/Download \
  "magnet:?xt=urn:btih:YOUR_INFO_HASH"
```

Replace the example magnet link with the complete magnet link you want to download.

Magnet links use the BitTorrent protocol. The download requires reachable peers and sufficient peer availability; speed depends on the swarm and network conditions.

### 3. Download using a local `.torrent` file

If the torrent file is already in your phone's Download folder:

```bash
aria2c --seed-time=0 \
  -d ~/storage/shared/Download \
  ~/storage/shared/Download/file.torrent
```

Replace `file.torrent` with the actual filename.

### 4. Download a `.torrent` file from a URL

```bash
aria2c --seed-time=0 \
  -d ~/storage/shared/Download \
  "TORRENT_FILE_URL"
```

This downloads the torrent file itself. To download the content described by that torrent, run `aria2c` again with the downloaded `.torrent` file as its input.

### 5. Run a download in the background

For a long download, you can disconnect from SSH while the process continues running, provided Android does not terminate Termux.

Example for a direct URL:

```bash
nohup aria2c -c -x 8 -s 8 \
  -d ~/storage/shared/Download \
  "DIRECT_DOWNLOAD_URL" \
  > ~/aria2-download.log 2>&1 < /dev/null &
```

Example for a magnet link:

```bash
nohup aria2c --seed-time=0 \
  -d ~/storage/shared/Download \
  "MAGNET_LINK" \
  > ~/aria2-download.log 2>&1 < /dev/null &
```

For a torrent file, replace `MAGNET_LINK` with the path to the `.torrent` file.

`--seed-time=0` tells aria2 not to continue seeding after a completed BitTorrent download.

### 6. Monitor download progress

View the log:

```bash
tail -f ~/aria2-download.log
```

Press `Ctrl+C` to stop viewing the log. This does not normally stop the background download.

Check whether aria2 is running:

```bash
pgrep -af aria2c
```

List downloaded files:

```bash
ls -lh ~/storage/shared/Download
```

To stop a background download, identify its process and terminate that process deliberately. Avoid killing unrelated processes.

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