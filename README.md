# server-termux

Turn an Android phone into an always-on server for Bun single-binary web apps, the same way
the POCO production phone is set up, minus the apps: sshd (key only), PostgreSQL (localhost),
PM2 with an empty app list, and a Cloudflare Tunnel, all under runit. Everything starts on boot
via Termux:Boot and is rechecked every 15 minutes by termux-job-scheduler.

`install.sh` is idempotent. Rerunning it repairs services without overwriting data, your app
list (`~/sites/ecosystem.config.js`), the tunnel config or the docs on the phone.

## New phone

1. Install the apps from F-Droid or GitHub (not the Play Store): **Termux**, **Termux:Boot**,
   **Termux:API**. Install **Tailscale** and log in.
2. In Termux (`NAME` = server and tunnel name, e.g. `poco2`):
   ```sh
   pkg upgrade -y && pkg install -y git
   git clone https://github.com/makurosolusi/server-termux ~/server-termux
   sh ~/server-termux/install.sh NAME
   ```
3. Tunnel: `cloudflared tunnel login`, open the URL, pick the domain, then rerun
   `sh ~/server-termux/install.sh NAME`. It creates tunnel `NAME` and `~/.cloudflared/config.yml`.
4. Do the Android settings the installer prints (child process restrictions off, autostart,
   no battery restrictions, Tailscale always-on, open Termux:Boot once), then reboot and unlock.
5. On the computer, add to `~/.ssh/config`:
   ```
   Host NAME
     HostName <tailscale ip of the phone>
     Port 8022
     User <user printed by the installer>
     IdentityFile ~/.ssh/id_ed25519_frpc
   ```

`authorized_keys` in this repo is the public key that may log in. Password login is turned off.

## What is where on the phone

| | |
|---|---|
| `~/README.md`, `~/sites/README.md` | Operating guide: add a site, domain, database, backup |
| `~/CLAUDE.md` (= `~/AGENTS.md`) | Rules for AI agents working on the phone |
| `~/sites/ecosystem.config.js` | PM2 app list |
| `$PREFIX/var/service/*` | runit services, logs in `$PREFIX/var/log/sv/*/current` |
| `~/bin/ensure-services` | Boot + watchdog, log in `~/.termux/ensure.log` |

Secrets (tunnel credentials, database passwords, app `.env`) are created on the phone and
never belong in this repo.

## Optional: containers

For software that is not a native binary (e.g. RustFS S3), install
[gvisor-termux](https://github.com/makurosolusi/gvisor-termux).
