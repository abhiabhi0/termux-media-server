# Legacy Jellyfin on 32-bit ARM Android

This guide documents the tested compatibility route for older Android phones where Termux reports 32-bit ARM (`arm`) and the native Jellyfin server package is unavailable.

> **Compatibility and security:** This uses Jellyfin `10.10.7+deb12` inside Debian Bookworm `armhf` under PRoot. It is an older Jellyfin release. Use it only on your local network or private Tailscale network; do not expose port `8096` directly to the public internet.

## 1. Install the legacy server

Open Termux on the phone and run:

```bash
curl -fsSL https://raw.githubusercontent.com/abhiabhi0/termux-media-server/main/setup-legacy-jellyfin.sh -o "$HOME/setup-legacy-jellyfin.sh" && bash "$HOME/setup-legacy-jellyfin.sh"
```

The installer:

- Installs `proot-distro` and Termux's FFmpeg.
- Creates Debian Bookworm with the `armhf` architecture, without replacing an existing container with a different architecture.
- Installs Jellyfin server and web packages at `10.10.7+deb12` from the official Jellyfin Debian repository.
- Runs Jellyfin in the background using Termux FFmpeg from inside PRoot and explicitly sets the web interface path.
- Installs service, status, and boot scripts and enables legacy Jellyfin in `start-media.sh`.

Verify the container architecture when troubleshooting:

```bash
proot-distro login debian -- dpkg --print-architecture
```

Expected output: `armhf`.

## 2. Keep the server running

Start the configured media services:

```bash
bash ~/bin/start-media.sh
```

Start legacy Jellyfin directly:

```bash
bash ~/bin/start-legacy-jellyfin.sh
```

Check the server and local web endpoints:

```bash
media-status
curl -sS http://127.0.0.1:8096/System/Info/Public
```

The normal Termux shell-start hook runs `start-media.sh`. The Termux:Boot hook runs it after Android restarts. To enable boot startup, install Termux:Boot from the same trusted source/signing channel as Termux and open Termux:Boot once.

In Android settings, set battery use for both Termux and Termux:Boot to **Unrestricted** (or the closest available option). `termux-wake-lock` can help prevent sleep while active, but Android may still kill background processes and cannot guarantee that a service runs forever.

Log files:

```bash
tail -f ~/.local/share/media-server-logs/jellyfin-legacy.log
tail -f ~/.local/share/media-server-logs/jellyfin-launcher.log
tail -f ~/.local/share/media-server-logs/boot.log
```

## 3. Open Jellyfin from a laptop using Tailscale

1. Install the Tailscale app on the phone and connect it to the same tailnet as the laptop.
2. Install/sign in to Tailscale on the laptop as well.
3. Find the phone's Tailscale IP in the Tailscale app or device list.
4. Open `http://PHONE_TAILSCALE_IP:8096` in the laptop browser. For example, replace the placeholder with the phone's actual `100.x.y.z` address.

Jellyfin's automatic server discovery may not find devices across Tailscale. In the Jellyfin web UI, choose **Add Server** and enter the full base address, such as `http://100.x.y.z:8096`. Do not append `/web` or a `#/selectserver.html` fragment to the server address.

Keep Tailscale connected on both devices. This setup does not configure Tailscale or hard-code a device IP into the scripts or repository.

## 4. Create the Jellyfin login

Jellyfin does not have a universal default username or password. On a new server, the first-run wizard asks you to create the initial Jellyfin username and password. Use those credentials at the sign-in screen afterward. They are separate from the Termux SSH password and File Browser password.

To check whether the server says the first-run wizard is complete:

```bash
curl -sS http://127.0.0.1:8096/System/Info/Public
```

The JSON includes `StartupWizardCompleted`.

- If it is `true`, Jellyfin believes initial setup is finished; sign in using the Jellyfin account that was created.
- If it is `false`, Jellyfin reports that the wizard is incomplete. Open the server's web address in a private browser window and try reconnecting to the base server URL.
- If the browser still shows **Please sign in** while `StartupWizardCompleted` is `false`, do not guess a default password and do not delete the database. Check the config/database state using the diagnostics below before changing anything.

Inspect the startup wizard flag and accounts inside Debian:

```bash
proot-distro login debian -- /bin/bash -lc '
grep -n "IsStartupWizardCompleted" /etc/jellyfin/system.xml 2>/dev/null || true
sqlite3 /var/lib/jellyfin/data/jellyfin.db "SELECT Username FROM Users;"
'
```

If `sqlite3` is missing in Debian, install it with `proot-distro login debian -- apt-get update` followed by `proot-distro login debian -- apt-get install -y sqlite3`. The user query is read-only. Do not publish database contents, tokens, or account information.

## 5. Add the phone's internal storage as a media library

In the Jellyfin web UI, open the dashboard and create or edit a library (for example, **Movies & Shows**) and add the internal shared-storage folder as a library folder.

Android's canonical path for internal shared storage is:

```text
/storage/emulated/0
```

This is the phone's shared internal storage, including folders such as `Download`, `Movies`, `DCIM`, and `Pictures`. It does not include private app data or protected Android system partitions.

### If the folder picker does not show `/storage/emulated/0`

The PRoot environment also exposes that same internal shared storage using the compatibility mount `/sdcard`. **In this setup, `/sdcard` is an alias for the phone's internal shared storage; it does not mean that a removable SD card is installed.** The Termux shared-storage shortcut `~/storage/shared` points to `/storage/emulated/0`.

To confirm the storage mount from Termux:

```bash
termux-setup-storage
ls -la ~/storage/shared
proot-distro login debian -- ls -la /sdcard
proot-distro login debian -- /bin/bash -lc 'su -p -s /bin/sh jellyfin -c "ls -la /sdcard | head -30"'
```

If Jellyfin's folder picker cannot enumerate `/storage/emulated/0`, enter `/sdcard` in the folder field and use the search/browse icon. Add that path if the picker accepts it. It points to the same internal shared storage through the PRoot mount.

After saving the library, run a library scan. Jellyfin will scan folders recursively, subject to Android storage permissions. Avoid selecting `/system` or the whole Linux `/` root; those paths are not your movie collection.

## 6. Troubleshooting

### The server URL opens, but the Jellyfin page cannot find a server

Automatic discovery may not work over Tailscale. Use **Add Server** and enter `http://PHONE_TAILSCALE_IP:8096`.

### Jellyfin is not reachable from the laptop

- Run `media-status` on the phone.
- Check `curl -I http://127.0.0.1:8096` in Termux.
- Confirm Tailscale is connected on both devices and that the phone's current Tailscale IP is correct.
- Inspect `jellyfin-legacy.log` and `jellyfin-launcher.log`.

### Jellyfin starts but FFmpeg validation fails

The Debian package's bundled FFmpeg can fail under Android/PRoot with a shared-library executable-stack permission error. The provided launcher uses the working Termux FFmpeg binary mounted at `/termux/bin/ffmpeg` and sets the web directory to `/usr/share/jellyfin/web`. Check that `ffmpeg -version` works in Termux, then run `bash ~/bin/start-legacy-jellyfin.sh` again.

### Android stops Jellyfin

Set Termux and Termux:Boot battery use to Unrestricted, keep the phone powered while streaming, and use `media-status` to verify recovery. Android process termination cannot be prevented completely.

## Password and privacy reminders

- Never commit Jellyfin usernames/passwords, File Browser credentials, SSH passwords, Tailscale addresses unique to your device, runtime databases, or logs to GitHub.
- Use Tailscale or your trusted local network for access. Do not publish port `8096` to the public internet.
- Jellyfin `10.10.7` is an older release used here for ARM32 compatibility; this setup is not a substitute for a supported current installation on 64-bit hardware.