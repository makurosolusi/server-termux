# Changelog

## [0.2.2] - 2026-11-28

### Changed
- `~/sites/README.md` is now written in English. The Indonesian version is kept in the repo as
  `files/home/sites/README.id.md` (not installed on the phone). Only new phones get the new text.

## [0.2.1] - 2026-11-27

### Changed
- The comments in `~/sites/ecosystem.config.js` and the PM2 service run script are now in English,
  and a broken `apps.json` is logged as `[ecosystem] apps.json skipped: …` (was `apps.json dilewati: …`).
  Only new phones get the new text; nothing else in the templates changed, and Panel Termux still
  accepts the previous template as it is.

## [0.2.0] - 2026-11-27

### Added
- Ready for Panel Termux: `~/sites/ecosystem.config.js` also loads the sites the panel creates from
  `~/sites/apps.json` (installed as `[]`, never overwritten on rerun). A missing, empty or broken
  `apps.json`, or an entry whose binary is not there yet, is skipped instead of stopping PM2.
- `pm2-guard` keep-alive app (`sleep infinity`) so PM2 stays up on a phone with no sites yet.
  Do not delete it; see `~/sites/README.md` ("Situs buatan panel").

### Changed
- The PM2 service exports `PM2_HOME=~/.pm2` explicitly.
- Only new phones get the new template; phones already running keep their own `ecosystem.config.js`.

## [0.1.0] - 2026-11-25

### Added
- `install.sh NAME` turns a fresh Termux into an always-on server: sshd (key only), PostgreSQL
  (localhost), PM2 with an empty app list and a Cloudflare Tunnel named `NAME`, all under runit.
- Services start on boot via Termux:Boot and are rechecked every 15 minutes by termux-job-scheduler.
- Safe to rerun as a repair: installs only missing packages and keeps data, the app list, the
  tunnel config and the docs on the phone.
- Operating guides on the phone: `~/README.md`, `~/sites/README.md` and `~/CLAUDE.md` (= `~/AGENTS.md`).
