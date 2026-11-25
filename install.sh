#!/data/data/com.termux/files/usr/bin/sh
# Usage: sh install.sh NAME — turn this Termux into an always-on server (sshd, postgres, pm2,
# cloudflared under runit, restarted on boot and every 15 min). Idempotent: rerun it to repair.
set -eu

NAME=${1:-}
[ -n "$NAME" ] || { echo "usage: sh install.sh NAME   (server and tunnel name, e.g. poco2)" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
export SVDIR=$PREFIX/var/service LOGDIR=$PREFIX/var/log
todo=

step() { printf '\n== %s\n' "$*"; }
die() { echo "install: $*" >&2; exit 1; }
later() { todo="$todo
  - $*"; }
missing() { for p; do dpkg -s "$p" >/dev/null 2>&1 || printf '%s ' "$p"; done; }
running() { sv status "$1" 2>/dev/null | grep -q '^run:'; }
# put SRC DEST [MODE]: copy from files/ with @NAME@ filled in, atomically.
put() { sed "s/@NAME@/$NAME/g" "$here/files/$1" > "$2.new" && chmod "${3:-644}" "$2.new" && mv "$2.new" "$2"; }
# Docs and the app list belong to the user after the first install.
put_once() { [ -f "$2" ] || put "$@"; }
svc_log() { mkdir -p "$SVDIR/$1/log" && ln -sf "$PREFIX/share/termux-services/svlogger" "$SVDIR/$1/log/run"; }
# Removing `down` does not start a service whose runsv is already running, so also `sv up`.
sv_on() {
  rm -f "$SVDIR/$1/down"
  i=0
  until sv status "$1" >/dev/null 2>&1; do
    i=$((i + 1)); [ $i -le 15 ] || die "runsv for $1 did not start (see $LOGDIR/sv/$1/current)"
    sleep 1
  done
  sv up "$1"
}

[ -d "${PREFIX:-}/bin" ] || die "run this inside Termux"
case $NAME in *[!a-z0-9-]*) die "NAME may only contain a-z, 0-9 and -" ;; esac

step packages
# Install only what is missing: a repair rerun must not upgrade openssh/postgres under a live server.
m=$(missing glibc-repo); [ -z "$m" ] || pkg install -y $m
m=$(missing openssh termux-services termux-api postgresql nodejs-lts cloudflared glibc-runner rsync procps nano)
[ -z "$m" ] || { apt-get update; pkg install -y $m; }

step ssh
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
ak=$HOME/.ssh/authorized_keys
touch "$ak" && chmod 600 "$ak"
grep -v '^#' "$here/authorized_keys" | grep . | while read -r k; do
  grep -qxF "$k" "$ak" || echo "$k" >> "$ak"
done
[ -s "$ak" ] || die "no key in $ak; refusing to turn off password login"
mkdir -p "$PREFIX/etc/ssh/sshd_config.d"
printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\n' > "$PREFIX/etc/ssh/sshd_config.d/10-key-only.conf"
sshd -t || die "sshd config is invalid"

step postgres
pgdata=$PREFIX/var/lib/postgresql
[ -f "$pgdata/PG_VERSION" ] || initdb -D "$pgdata" -U postgres --auth-local=trust --auth-host=scram-sha-256 >/dev/null

step pm2
command -v pm2 >/dev/null || npm install -g pm2
mkdir -p "$HOME/sites"
put_once sites/ecosystem.config.js "$HOME/sites/ecosystem.config.js"
if [ ! -d "$HOME/.pm2/modules/pm2-logrotate" ]; then
  pm2 install pm2-logrotate >/dev/null
  pm2 set pm2-logrotate:max_size 10M >/dev/null
  pm2 set pm2-logrotate:retain 7 >/dev/null
  pm2 set pm2-logrotate:compress true >/dev/null
fi
# pm2 CLI commands spawn their own daemon when pm2-runtime is down; it would fight runit's pm2.
running pm2 || pm2 kill >/dev/null
mkdir -p "$SVDIR/pm2" && put sv/pm2/run "$SVDIR/pm2/run" 755 && svc_log pm2

step cloudflared
cf=$HOME/.cloudflared
mkdir -p "$SVDIR/cloudflared" && put sv/cloudflared/run "$SVDIR/cloudflared/run" 755 && svc_log cloudflared
if [ ! -f "$cf/config.yml" ] && [ -f "$cf/cert.pem" ]; then
  cloudflared tunnel create "$NAME" || die "could not create tunnel $NAME (name already used in the account?)"
  id=$(cloudflared tunnel list -n "$NAME" -o json | grep -o '"id": *"[0-9a-f-]*"' | head -1 | grep -o '[0-9a-f-]\{36\}')
  [ -f "$cf/$id.json" ] || die "credentials for tunnel $NAME ($id) not found in $cf"
  printf 'tunnel: %s\ncredentials-file: %s/%s.json\ningress:\n  - service: http_status:404\n' "$id" "$cf" "$id" > "$cf/config.yml"
fi
[ -f "$cf/config.yml" ] || {
  touch "$SVDIR/cloudflared/down"
  later "tunnel: run 'cloudflared tunnel login' (open the URL, pick the domain), then rerun: sh $here/install.sh $NAME"
}

step boot + watchdog
mkdir -p "$HOME/bin" "$HOME/.termux/boot"
put bin/ensure-services "$HOME/bin/ensure-services" 755
put .termux/boot/start-services "$HOME/.termux/boot/start-services" 755
timeout 20 termux-job-scheduler --job-id 1 --period-ms 900000 --persisted true --script "$HOME/bin/ensure-services" >/dev/null ||
  later "watchdog job not scheduled: install the Termux:API app, then rerun install.sh"
sh "$HOME/bin/ensure-services" manual
for s in sshd postgres pm2; do sv_on $s; done
[ ! -f "$cf/config.yml" ] || sv_on cloudflared

step docs
put_once home/README.md "$HOME/README.md"
put_once home/CLAUDE.md "$HOME/CLAUDE.md"
ln -sf CLAUDE.md "$HOME/AGENTS.md"
put_once home/sites/README.md "$HOME/sites/README.md"

step check
up="sshd postgres pm2"; [ ! -f "$cf/config.yml" ] || up="$up cloudflared"
sv -w 30 check $up || die "a service is not running; see $LOGDIR/sv/<name>/current"
i=0; until pg_isready -q -h 127.0.0.1; do i=$((i + 1)); [ $i -le 15 ] || die "postgres not accepting connections"; sleep 1; done
echo "server $NAME: $up running"

cat <<EOF

== Android settings (cannot be done from Termux, check once per phone):
  1. Developer options -> "Disable child process restrictions" ON
     (or from a computer: adb shell settings put global settings_enable_monitor_phantom_procs false)
  2. Termux, Termux:Boot, Termux:API, Tailscale: Autostart ON, Battery = No restrictions
  3. Tailscale: Always-on VPN ON
  4. Open the Termux:Boot app once
  Then reboot, unlock once, and from the computer: ssh -p 8022 $(id -un)@<tailscale-ip>
EOF
[ -z "$todo" ] || printf '\n== Still to do:%s\n' "$todo"
