# Android + Windows Personal Media Server (Termux)

A reusable setup for turning a compatible Android phone into a private media/file server, managed from Windows. It uses Termux, Jellyfin, File Browser, OpenSSH, aria2, and optionally Tailscale.

> **Compatibility:** The setup script is intended for Termux on Android. Jellyfin packages are not available for every Android CPU architecture or Termux repository combination. The script detects architecture for File Browser, but stops if Jellyfin packages cannot be installed. Test on your phone before relying on it. It is not a universal one-click installer for every Android device.

## What the Android setup script does

- Updates Termux packages and installs `openssh`, `curl`, `wget`, `jq`, `tar`, `gzip`, `aria2`, and Python.
- Requests access to Android shared storage (`termux-setup-storage`).
- Installs `jellyfin-server` and `jellyfin-ffmpeg` from configured Termux repositories.
- Downloads the matching File Browser release binary for supported CPU architectures.
- Creates a password-protected File Browser admin account on first setup; preserves existing database/password on reruns.
- Creates `~/bin/start-media.sh` to start SSH, Jellyfin, and File Browser when not already running.
- Adds a duplicate-checked `.bashrc` hook so services start when a Termux shell opens.
- Logs service output under `~/.local/share/media-server-logs/`.
- Does not reset existing Jellyfin data, File Browser credentials, Android DNS, or Tailscale configuration.

## Files

- `setup-media-server.sh` — run in Termux on Android.
- `windows-connect.ps1` — optional Windows helper to test ports and print SSH/browser URLs.
- `README.md` — this guide.

## Android setup

1. Install Termux from a trusted source such as the official F-Droid listing or Termux GitHub releases. Avoid mixing Termux and add-on apps from different signing sources.
2. Download `setup-media-server.sh` to your phone's Download folder, or clone/download this repository.
3. Open Termux and run:

```bash
termux-setup-storage
cd ~/storage/shared/Download
bash setup-media-server.sh
```

If you cloned the repository into Termux home, run:

```bash
bash ~/android-windows-media-server/setup-media-server.sh
```

Grant the Android storage permission when prompted. The script asks for a File Browser admin password only if it is creating the database for the first time.

### Android-specific follow-up

- Open Jellyfin in a browser at `http://127.0.0.1:8096` and complete the first-run wizard if needed.
- In Android settings, set Termux battery usage to **Unrestricted** / **Don't optimize** if available. Android may still stop background processes.
- `termux-wake-lock` can help keep the CPU awake but does not override all OS restrictions.
- The `.bashrc` hook starts services when a Termux shell opens. For startup immediately after a phone reboot, install and configure the compatible Termux:Boot add-on separately.
- Keep File Browser authentication enabled. Do not expose ports directly to the public internet.

## Windows setup

1. Install Tailscale on Windows and Android, sign in to the same account, and ensure both devices show as connected.
2. In Tailscale, find the Android phone's Tailscale IP and/or MagicDNS name.
3. Open PowerShell in the repository folder and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows-connect.ps1
```

Or use the URLs/commands manually, replacing the hostname and username:

```powershell
Test-NetConnection YOUR_PHONE_TAILSCALE_IP -Port 8022
Test-NetConnection YOUR_PHONE_TAILSCALE_IP -Port 8096
Test-NetConnection YOUR_PHONE_TAILSCALE_IP -Port 8080
ssh -p 8022 YOUR_TERMUX_USERNAME@YOUR_PHONE_TAILSCALE_IP
```

### Services

- Jellyfin: `http://YOUR_PHONE_TAILSCALE_IP:8096`
- File Browser: `http://YOUR_PHONE_TAILSCALE_IP:8080`
- SSH: `ssh -p 8022 YOUR_TERMUX_USERNAME@YOUR_PHONE_TAILSCALE_IP`

Use the Tailscale IP if MagicDNS doesn't resolve. If using MagicDNS, use the full name shown by Tailscale.

## Download directly to Android from Windows

Connect to Termux using SSH:

```powershell
ssh -p 8022 YOUR_TERMUX_USERNAME@YOUR_PHONE_TAILSCALE_IP
```

Then run this in the SSH session:

```bash
aria2c -c -x 8 -s 8 -d ~/storage/shared/Download "DIRECT_DOWNLOAD_URL"
```

- `-c` resumes supported interrupted downloads.
- `-x 8` allows up to 8 connections per server.
- `-s 8` requests up to 8 segments.
- `-d` selects the Android shared Download folder.

Some sites require authentication or do not allow direct download tools; a normal webpage URL may not be a direct file URL.

To run in the background and log output:

```bash
nohup aria2c -c -x 8 -s 8 -d ~/storage/shared/Download "DIRECT_DOWNLOAD_URL" > ~/aria2-download.log 2>&1 < /dev/null &
```

Watch the log:

```bash
tail -f ~/aria2-download.log
```

Press `Ctrl+C` to stop viewing the log; it does not stop the background download.

## Useful Termux commands

```bash
# Start services if not already running
bash ~/bin/start-media.sh

# Check processes
pgrep -af jellyfin
pgrep -af filebrowser
pgrep -af sshd

# Test Jellyfin and File Browser locally
curl -I http://127.0.0.1:8096
curl -I http://127.0.0.1:8080

# Read logs
tail -f ~/.local/share/media-server-logs/jellyfin.log
tail -f ~/.local/share/media-server-logs/filebrowser.log
```

## DNS / privacy notes

- Tailscale provides private connectivity between signed-in devices; it does not replace the need for the services to be running.
- Android Private DNS (for example, AdGuard DNS) and Tailscale DNS can conflict depending on configuration. If internet stops when Tailscale connects, check the Tailscale DNS option before changing Android Private DNS.
- If MagicDNS names do not resolve, use the Tailscale IP.
- Never publish passwords, private keys, Tailscale auth keys, or File Browser databases in a public repository.

## Windows requirements

- Windows 10/11.
- Tailscale app installed and connected for private remote access.
- OpenSSH Client available (usually included in modern Windows; check `ssh -V`).
- Git is optional unless cloning the repository.

## Troubleshooting

- **Jellyfin doesn't start:** check `~/.local/share/media-server-logs/jellyfin.log`; verify Jellyfin package availability for the Termux architecture.
- **SSH works but Jellyfin doesn't:** run `curl -I http://127.0.0.1:8096` on the phone, then test port 8096 from Windows.
- **MagicDNS doesn't resolve:** try the phone's Tailscale IP.
- **File Browser login:** the first-run password is set during setup. Existing credentials are not reset by rerunning the script.
- **Services stop in background:** check Android battery restrictions and Termux notifications; Android can kill background processes.
