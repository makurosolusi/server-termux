#!/bin/sh
# Runs install.sh against stubbed Termux tools in a temp dir: first install, repair rerun, tunnel.
set -eu
repo=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
export PREFIX=$t/usr HOME=$t/home STUB_LOG=$t/calls
mkdir -p "$PREFIX/bin" "$PREFIX/share/termux-services" "$HOME" "$t/installed"
# What the openssh/postgresql/cloudflared packages ship: service dirs that start disabled.
for s in sshd postgres cloudflared; do mkdir -p "$PREFIX/var/service/$s" && touch "$PREFIX/var/service/$s/down"; done
uuid=11111111-2222-3333-4444-555555555555

stub() { printf '#!/bin/sh\n%s\n' "$2" > "$PREFIX/bin/$1"; chmod 755 "$PREFIX/bin/$1"; }
stub dpkg "[ -f $t/installed/\$2 ]"
stub pkg "echo \"pkg \$*\" >> \$STUB_LOG; shift 2; for p; do touch $t/installed/\$p; done"
stub apt-get ':'
stub sv "case \$1 in status) [ -d \"\$SVDIR/\$2\" ] && echo \"run: \$2\";; -w) echo \"sv \$*\" >> \$STUB_LOG;; esac"
stub initdb "mkdir -p \"\$2\" && touch \"\$2/PG_VERSION\""
stub pm2 "echo \"pm2 \$*\" >> \$STUB_LOG; [ \"\$1\" = install ] && mkdir -p \$HOME/.pm2/modules/pm2-logrotate; :"
stub cloudflared "case \$2 in create) echo '{}' > \$HOME/.cloudflared/$uuid.json;; list) echo '[{\"id\":\"$uuid\",\"name\":\"x\"}]';; esac"
stub timeout 'shift; exec "$@"'
for c in sshd npm pg_isready service-daemon termux-wake-lock termux-job-scheduler; do stub $c ':'; done
export PATH=$PREFIX/bin:$PATH

fail() { echo "FAIL: $*" >&2; exit 1; }
run() { sh "$repo/install.sh" "$@" > "$t/out" 2>&1 || { rc=$?; cat "$t/out"; fail "install.sh $* exited $rc"; }; }

# 1. bad name is refused
sh "$repo/install.sh" 'Bad Name' >/dev/null 2>&1 && fail "bad NAME accepted"

# 2. first install, no cloudflared login yet
run srv1
sv=$PREFIX/var/service
[ -x "$HOME/bin/ensure-services" ] && [ -x "$HOME/.termux/boot/start-services" ] || fail "boot scripts"
[ -x "$sv/pm2/run" ] && [ -L "$sv/pm2/log/run" ] || fail "pm2 service"
grep -q -- --no-auto-exit "$sv/pm2/run" || fail "pm2-runtime would exit with no apps"
[ -f "$sv/cloudflared/down" ] || fail "cloudflared must stay down without a tunnel"
grep -q 'cloudflared tunnel login' "$t/out" || fail "tunnel todo not printed"
grep -q 'PasswordAuthentication no' "$PREFIX/etc/ssh/sshd_config.d/10-key-only.conf" || fail "key-only"
[ "$(grep -c . "$HOME/.ssh/authorized_keys")" = 1 ] || fail "authorized_keys"
grep -q 'srv1' "$HOME/README.md" && ! grep -rq '@NAME@' "$HOME/README.md" "$HOME/CLAUDE.md" "$HOME/sites/README.md" || fail "docs NAME"
[ -L "$HOME/AGENTS.md" ] || fail "AGENTS.md link"
grep -q 'pm2 kill' "$STUB_LOG" || fail "stray pm2 daemon not killed"
grep -q 'sv -w 30 check sshd postgres pm2$' "$STUB_LOG" || fail "check"

# 3. repair rerun: nothing reinstalled, user edits kept, no duplicate key
echo edited > "$HOME/README.md"; echo '// mine' > "$HOME/sites/ecosystem.config.js"
: > "$STUB_LOG"
run srv1
grep -q '^pkg' "$STUB_LOG" && fail "rerun reinstalled packages"
[ "$(cat "$HOME/README.md")" = edited ] && [ "$(cat "$HOME/sites/ecosystem.config.js")" = '// mine' ] || fail "user files overwritten"
[ "$(grep -c . "$HOME/.ssh/authorized_keys")" = 1 ] || fail "key duplicated"

# 4. after `cloudflared tunnel login`: tunnel created, config by UUID, service enabled
touch "$HOME/.cloudflared/cert.pem" 2>/dev/null || { mkdir -p "$HOME/.cloudflared"; touch "$HOME/.cloudflared/cert.pem"; }
run srv1
grep -q "^tunnel: $uuid\$" "$HOME/.cloudflared/config.yml" || fail "config.yml tunnel"
grep -q 'http_status:404' "$HOME/.cloudflared/config.yml" || fail "config.yml ingress"
[ ! -f "$sv/cloudflared/down" ] || fail "cloudflared still down"
grep -q 'check sshd postgres pm2 cloudflared' "$STUB_LOG" || fail "cloudflared not checked"

echo "install.test: all passed"
