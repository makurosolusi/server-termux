# Changelog

## [0.1.0] - 2026-11-25

### Added
- `install.sh NAME` turns a fresh Termux into an always-on server: sshd (key only), PostgreSQL
  (localhost), PM2 with an empty app list and a Cloudflare Tunnel named `NAME`, all under runit.
- Services start on boot via Termux:Boot and are rechecked every 15 minutes by termux-job-scheduler.
- Safe to rerun as a repair: installs only missing packages and keeps data, the app list, the
  tunnel config and the docs on the phone.
- Operating guides on the phone: `~/README.md`, `~/sites/README.md` and `~/CLAUDE.md` (= `~/AGENTS.md`).
