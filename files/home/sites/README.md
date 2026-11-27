English | [Bahasa Indonesia](README.id.md)

# Sites on this phone

This Android phone (Termux), `@NAME@` (`ssh @NAME@`, Cloudflare tunnel `@NAME@`), is used as a server. Every website is **one folder** in `~/sites/` and **one line** in `~/sites/ecosystem.config.js`, and is run by **PM2**.

```
Internet → Cloudflare → cloudflared (on the phone) → http://localhost:<PORT> → app
runit (Termux:Boot) ─┬─ sshd, postgres, cloudflared
                     └─ pm2 ── every app in ~/sites
```

- **PM2** runs the apps, restarts the ones that crash, and provides `pm2 ls` / `pm2 logs` / `pm2 restart`.
- **runit** keeps PM2 itself, sshd, postgres and cloudflared running, and starts them all again after a reboot (via Termux:Boot). `pm2 startup` is **not used** because Termux has no systemd.
- **cloudflared** exposes public domains without needing a public IP.
- **postgres** is a single instance, reachable only from the phone itself (localhost).

## Site list

| Site | Domain | Port | Database |
|---|---|---|---|
| *(none yet)* | | | |

> Add a row to this table every time you add a site.

## Sites created by the panel

Besides the `site('<name>')` lines you write yourself, `ecosystem.config.js` also loads:

- **`pm2-guard`**: a keep-alive app (`sleep infinity`, about 1 MB). pm2-runtime exits when there is no app at
  all at startup, even with `--no-auto-exit`, so this guard keeps it alive on a phone that has no sites yet.
  **Do not delete it** from `ecosystem.config.js` and do not run `pm2 delete pm2-guard`.
- **`apps.json`** (`~/sites/apps.json`): the list of sites created by Panel Termux, loaded automatically by the
  `panelApps` block in `ecosystem.config.js`. This file is **managed by the panel, do not edit it by hand**.
  If it is missing, empty or broken, the ecosystem still runs without the panel sites; entries whose binary
  does not exist yet are skipped.
- Do not delete a panel site's `app` over ssh without deleting the site in the panel. Delete the site from the panel.

## What is inside a site folder

```
~/sites/<site>/
├── app     application binary (Bun single binary, run through grun)
├── .env    configuration + secrets (chmod 600, do NOT cat/share it)
└── data/   the app's own data
```

| What | Where |
|---|---|
| PM2 app list | `~/sites/ecosystem.config.js` (+ panel sites in `~/sites/apps.json`) |
| App logs | `~/.pm2/logs/<site>-out.log` and `-error.log` (rotated by `pm2-logrotate`: 10M, keep 7) |
| PM2 runit service | `$PREFIX/var/service/pm2/run`, log at `$PREFIX/var/log/sv/pm2/current` |
| Domain routing | `~/.cloudflared/config.yml` |
| Postgres data | `$PREFIX/var/lib/postgresql` |

## Everyday commands

```sh
pm2 ls                 # status of all apps
pm2 logs <site>        # live logs (Ctrl+C to exit)
pm2 restart <site>     # restart (for example after changing .env)
pm2 monit              # CPU/RAM dashboard
```

To stop an app **permanently** (also after a reboot): remove its line from `ecosystem.config.js`, then run `pm2 delete <site>`.

Services outside PM2 (when going through `ssh @NAME@ '…'`, prefix the command with `export SVDIR=$PREFIX/var/service;`):

```sh
sv status pm2 postgres cloudflared sshd
sv restart pm2         # restart PM2 and all its apps
```

## Adding a new site

Example: site name `blog`, port `3006`, domain `blog.example.com`.

1. **Folder and binary.** Build on your computer with `bun build --compile --target=bun-linux-arm64`, then:
   ```sh
   mkdir -p ~/sites/blog
   rsync --partial -t <binary> @NAME@:sites/blog/app      # from your computer; rerun if the connection drops
   chmod +x ~/sites/blog/app
   ```
2. **`.env`** with a **unique port** (check the table above):
   ```sh
   cd ~/sites/blog && umask 077 && nano .env   # at minimum PORT=3006, plus any env the app needs
   ```
3. **Database** (if needed):
   ```sh
   psql -U postgres -c "CREATE ROLE blog LOGIN;" -c "CREATE DATABASE blog OWNER blog;"
   psql -U postgres -c "\password blog"   # type the password at the prompt, do not put it in the command
   # DATABASE_URL=postgres://blog:<password>@127.0.0.1:5432/blog  → put it in .env
   ```
   To run migrations from your computer, open a tunnel first: `ssh -N -L 15432:127.0.0.1:5432 @NAME@`.
4. **Register it with PM2.** In `~/sites/ecosystem.config.js`, add `site('blog'),` to `apps`, then:
   ```sh
   pm2 start ~/sites/ecosystem.config.js --only blog
   ```
   No `pm2 save` is needed, because PM2 reads this file every time it starts.
5. **Domain.** Add this to `~/.cloudflared/config.yml`, **above** the `- service: http_status:404` line:
   ```yaml
     - hostname: blog.example.com
       service: http://localhost:3006
   ```
   Then run:
   ```sh
   cloudflared tunnel route dns @NAME@ blog.example.com
   sv restart cloudflared
   ```
6. Add a row to the **Site list** above.

## Updating an app version

```sh
rsync --partial -t <new-binary> @NAME@:sites/<site>/app.new    # from your computer
cd ~/sites/<site> && mv app app.prev && mv app.new app && chmod +x app && pm2 restart <site>
# rollback: mv app.prev app && pm2 restart <site>
```

## Database backup

```sh
mkdir -p ~/backups
pg_dump -U postgres -Fc <db> > ~/backups/<db>-$(date +%F).dump
# restore: pg_restore -U postgres -d <db> --clean ~/backups/<file>.dump
```

> A backup that only lives on the phone is lost if the phone breaks. Copy it to your computer or the cloud regularly.

## Things to remember

- **Never `cat .env`** or show it on screen/in chat.
- **Never run `pkill -f <name>` / `pgrep -f` over ssh**, because it can kill the ssh shell itself.
- **Node** comes from the `nodejs-lts` package (not nvm). After Node is upgraded, run `npm i -g pm2 && sv restart pm2`.
- After a `pkg upgrade` that also upgrades `openssh`, run `sv restart sshd`.
- If PM2 dies hard, an app can be left holding its port. The pm2 `run` script automatically kills orphaned apps under `~/sites/*` before PM2 starts again.

## Troubleshooting

| Symptom | Check |
|---|---|
| Domain shows 502/1033 | `pm2 ls` and `sv status cloudflared`, then read the logs of both |
| App keeps restarting | `pm2 logs <site> --lines 50` (`EADDRINUSE` = port conflict) |
| `pm2 ls` is empty / errors | `sv status pm2`, `tail -50 $PREFIX/var/log/sv/pm2/current` |
| Not running after a reboot | Make sure the screen was unlocked once, check for a `by=boot` line in `~/.termux/ensure.log`, then review the phone settings in `~/README.md` |
| Cannot ssh | If it times out: check Tailscale on the phone and the computer. If refused: in Termux on the phone run `sv up $PREFIX/var/service/sshd` (or `sshd`) |
| Anything else is broken | `sh ~/server-termux/install.sh @NAME@` (safe to rerun) |
