#!/bin/bash
# Builds a self-contained dist/Liberated-linux/ folder (nginx + PHP 8 FPM + Python 3 venv w/ dnslib + site content).
# Everything lives inside the folder; deleting it removes everything.
# Requires: gcc/cc, make, perl, curl, tar (e.g. `sudo apt install build-essential curl`).
set -euo pipefail

NGINX_VERSION="1.26.2"
OPENSSL_VERSION="3.0.15"
PCRE2_VERSION="10.44"
ZLIB_VERSION="1.3.1"
PHP_VERSION="8.3.32"
PY_VERSION="3.12.7"
PY_RELEASE="20241016"

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/dist/Liberated-linux"
RES="$OUT/resources"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

case "$(uname -m)" in
  x86_64)        ARCH="x86_64" ;;
  aarch64|arm64) ARCH="aarch64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

for tool in cc make perl curl tar; do
  command -v "$tool" >/dev/null || { echo "Missing '$tool' (try: sudo apt install build-essential curl)" >&2; exit 1; }
done

fetch() { echo "==> Downloading $1"; curl -fL --retry 3 -o "$2" "$1"; }
JOBS="$(nproc 2>/dev/null || echo 2)"

rm -rf "$OUT"
mkdir -p "$RES"/{bin,php,dns,run} "$RES/web"/{conf,logs,temp}

# ---------------------------------------------------------------- nginx
cd "$WORK"
fetch "https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz" nginx.tgz
fetch "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz" openssl.tgz
fetch "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$PCRE2_VERSION/pcre2-$PCRE2_VERSION.tar.gz" pcre2.tgz
fetch "https://github.com/madler/zlib/releases/download/v$ZLIB_VERSION/zlib-$ZLIB_VERSION.tar.gz" zlib.tgz
for f in nginx openssl pcre2 zlib; do tar -xzf "$f.tgz"; done

echo "==> Building nginx (statically linked against OpenSSL/PCRE2/zlib)"
cd "$WORK/nginx-$NGINX_VERSION"
# Relative paths resolve against the -p prefix at runtime, keeping nginx relocatable.
./configure \
  --prefix=/nonexistent \
  --conf-path=conf/nginx.conf \
  --error-log-path=logs/error.log \
  --http-log-path=logs/access.log \
  --pid-path=logs/nginx.pid \
  --lock-path=logs/nginx.lock \
  --http-client-body-temp-path=temp/client_body \
  --http-fastcgi-temp-path=temp/fastcgi \
  --with-http_ssl_module \
  --with-pcre="$WORK/pcre2-$PCRE2_VERSION" --with-pcre-jit \
  --with-zlib="$WORK/zlib-$ZLIB_VERSION" \
  --with-openssl="$WORK/openssl-$OPENSSL_VERSION" \
  --without-http_proxy_module \
  --without-http_uwsgi_module \
  --without-http_scgi_module
make -j"$JOBS"
cp objs/nginx "$RES/bin/nginx"

# ---------------------------------------------------------------- PHP 8 (static php-fpm)
cd "$WORK"
fetch "https://dl.static-php.dev/static-php-cli/common/php-$PHP_VERSION-fpm-linux-$ARCH.tar.gz" php.tgz
mkdir php && tar -xzf php.tgz -C php
cp "$(find php -type f -name php-fpm | head -n1)" "$RES/php/php-fpm"
chmod +x "$RES/php/php-fpm"

# Reuse the project's php.ini; extensions are compiled into the static binary.
sed -E 's/^(extension|zend_extension|extension_dir)[[:space:]]*=/;&/' "$ROOT/php/php.ini" > "$RES/php/php.ini"

cat > "$RES/php/php-fpm.conf" <<'EOF'
; Relative paths resolve against the -p prefix (resources/)
[global]
pid = run/php-fpm.pid
error_log = run/php-fpm.log
daemonize = yes

[www]
listen = 127.0.0.1:9123
pm = static
pm.max_children = 4
catch_workers_output = yes
EOF

# ---------------------------------------------------------------- Python 3 + venv + dnslib
fetch "https://github.com/astral-sh/python-build-standalone/releases/download/$PY_RELEASE/cpython-$PY_VERSION+$PY_RELEASE-$ARCH-unknown-linux-gnu-install_only.tar.gz" python.tgz
tar -xzf python.tgz -C "$RES"   # extracts to $RES/python

echo "==> Creating venv and installing dnslib"
"$RES/python/bin/python3" -m venv "$RES/venv"
PIP_DISABLE_PIP_VERSION_CHECK=1 "$RES/venv/bin/python3" -m pip install --no-cache-dir dnslib certifi

# Make the venv interpreter links relative so the folder can be moved
for link in "$RES"/venv/bin/python*; do
  if [ -L "$link" ] && [[ "$(readlink "$link")" == /* ]]; then
    ln -sfn "../../python/bin/python3" "$link"
  fi
done

cp "$ROOT/dnsserver.py" "$RES/dns/dnsserver.py"
cp "$ROOT/icon.png" "$RES/icon.png"
mkdir -p "$RES/scraper"
cp "$ROOT/scraper/scraper.py" "$ROOT/scraper/scraper-config.json" "$RES/scraper/"

# ---------------------------------------------------------------- Site content + nginx config
echo "==> Copying site content"
cp -a "$ROOT/web/html" "$RES/web/html"
cp "$ROOT/web/conf/fastcgi_params" "$RES/web/conf/"
cp -a "$ROOT/web/conf/ssl" "$RES/web/conf/ssl"

cat > "$RES/web/conf/nginx.conf" <<'EOF'
worker_processes 1;
error_log logs/error.log;
pid       logs/nginx.pid;

events { worker_connections 1024; }

http {
    client_body_temp_path temp/client_body;
    fastcgi_temp_path     temp/fastcgi;
    access_log            logs/access.log;

    server {
        listen 80;
        listen 443 ssl;
        server_name d2-megaten-l.sega.com d2r-dl.d2megaten.com d2r-sim.d2megaten.com d2r-chat.d2megaten.com liberated.dx2 localhost;

        ssl_certificate     ssl/site.crt;
        ssl_certificate_key ssl/site.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:MD5;

        root  html;
        index index.php index.html index.htm;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.(do|php)$ {
            include fastcgi_params;
            fastcgi_pass 127.0.0.1:9123;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }
    }
}
EOF

# ---------------------------------------------------------------- Root helper (Linux needs root for ports < 1024)
cat > "$RES/bin/privileged.sh" <<'EOF'
#!/bin/bash
# Runs as root. Starts nginx + DNS, reports status, then tears down once the launcher exits.
LAUNCHER_PID="$1"
RUN_USER="$2"
IP="${3:-}"
RES="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$RES/run"
RUN_GROUP="$(id -gn "$RUN_USER")"
export PYTHONDONTWRITEBYTECODE=1   # no root-owned __pycache__ inside the folder

nginx_ctl() { "$RES/bin/nginx" -p "$RES/web/" -e logs/error.log -c conf/nginx.conf "$@"; }

cleanup() {
  nginx_ctl -s quit 2>/dev/null
  [ -n "${DNS_PID:-}" ] && kill "$DNS_PID" 2>/dev/null
  sleep 1
  # Hand root-created files back to the user so the folder can be deleted without sudo
  chown -R "$RUN_USER:$RUN_GROUP" "$RES/web/logs" "$RES/web/temp" "$RUN" 2>/dev/null
}
trap cleanup EXIT
trap 'exit 0' TERM INT HUP

status="ok"
if ! nginx_ctl -g "user $RUN_USER $RUN_GROUP;" >> "$RUN/nginx-start.log" 2>&1; then
  status="nginx failed to start (are ports 80/443 in use?). See resources/web/logs/error.log"
else
  "$RES/venv/bin/python3" -u "$RES/dns/dnsserver.py" "$IP" >> "$RUN/dns.log" 2>&1 &
  DNS_PID=$!
  sleep 1
  kill -0 "$DNS_PID" 2>/dev/null \
    || status="DNS server failed to start (is port 53 in use, e.g. by systemd-resolved?). See resources/run/dns.log"
fi
echo "$status" > "$RUN/helper.status"
[ "$status" = "ok" ] || exit 1

while kill -0 "$LAUNCHER_PID" 2>/dev/null; do sleep 2; done
EOF

# ---------------------------------------------------------------- Launcher
cat > "$OUT/Liberated" <<'EOF'
#!/bin/bash
set -u
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
RES="$HERE/resources"
RUN="$RES/run"
ICON="$RES/icon.png"
mkdir -p "$RUN" "$RES/web/logs" "$RES/web/temp"
rm -f "$RUN/helper.status"

# Keep the desktop entry pointing at this folder (it may have been moved)
if [ -w "$HERE" ]; then
  cat > "$HERE/Liberated.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Liberated
Comment=Liberated server (DNS + web)
Exec="$HERE/Liberated"
Icon=$ICON
Terminal=false
Categories=Network;
DESKTOP
  chmod +x "$HERE/Liberated.desktop"
fi

msg() {
  if command -v zenity >/dev/null; then
    zenity --info --no-wrap --title=Liberated --window-icon="$ICON" --text="$1" --ok-label="${2:-OK}" 2>/dev/null
  elif command -v kdialog >/dev/null; then
    kdialog --title Liberated --msgbox "$1" 2>/dev/null
  elif [ -t 0 ]; then
    printf '%s\n' "$1"; read -r -p "Press Enter to ${2:-continue}... "
  else
    printf '%s\n' "$1" >&2
    return 1
  fi
}

confirm() {
  if command -v zenity >/dev/null; then
    zenity --question --no-wrap --title=Liberated --window-icon="$ICON" --text="$1" --ok-label=Download --cancel-label=Skip 2>/dev/null
  elif command -v kdialog >/dev/null; then
    kdialog --title Liberated --yes-label Download --no-label Skip --yesno "$1" 2>/dev/null
  elif [ -t 0 ]; then
    local answer; read -r -p "$1 [y/N] " answer; [[ "$answer" =~ ^[Yy] ]]
  else
    return 1
  fi
}

PY="$RES/venv/bin/python3"
SCRAPER="$RES/scraper/scraper.py"
LOG="$RUN/scraper.log"

# Turns "[done/total] name" scraper lines into zenity --progress percentages and status text
to_zenity_progress() {
  local line pct re='^\[([0-9]+)/([0-9]+)\]'
  while IFS= read -r line; do
    if [[ $line =~ $re ]] && (( BASH_REMATCH[2] > 0 )); then
      pct=$(( BASH_REMATCH[1] * 100 / BASH_REMATCH[2] ))
      (( pct > 99 )) && pct=99   # 100 auto-closes the dialog; save it for the end
      echo "$pct"
    fi
    if [[ $line == __EXIT__* ]]; then echo 100; else echo "# $line"; fi
  done
}

download_assets() {
  # __EXIT__ marker records the scraper's exit code; it's missing if the download was cancelled
  if command -v zenity >/dev/null; then
    { "$PY" -u "$SCRAPER" 2>&1; echo "__EXIT__$?"; } | tee "$LOG" | to_zenity_progress \
      | zenity --progress --auto-close --percentage=0 --title=Liberated --window-icon="$ICON" \
          --text="Downloading game assets..." 2>/dev/null
  elif [ -t 1 ]; then
    { "$PY" -u "$SCRAPER" 2>&1; echo "__EXIT__$?"; } | tee "$LOG"
  else
    command -v kdialog >/dev/null && kdialog --title Liberated --passivepopup "Downloading game assets..." 5 2>/dev/null
    { "$PY" -u "$SCRAPER" 2>&1; echo "__EXIT__$?"; } > "$LOG"
  fi
  if grep -q '^__EXIT__0$' "$LOG"; then
    msg "Game assets downloaded."
  elif grep -q '^__EXIT__' "$LOG"; then
    msg "Asset download failed: $(grep -v '^__EXIT__' "$LOG" | tail -n 1) (see $LOG)"
  else
    msg "Asset download cancelled. Files downloaded so far are kept."
  fi
}

# Prints "stop", "update", or "none" (no way to ask)
menu() {
  if command -v zenity >/dev/null; then
    local out
    out="$(zenity --info --no-wrap --title=Liberated --window-icon="$ICON" --text="$1" \
      --ok-label=Stop --extra-button="Update Assets" 2>/dev/null)"
    [ "$out" = "Update Assets" ] && echo update || echo stop
  elif command -v kdialog >/dev/null; then
    kdialog --title Liberated --yes-label Stop --no-label "Update Assets" --yesno "$1" 2>/dev/null
    [ $? -eq 1 ] && echo update || echo stop
  elif [ -t 0 ]; then
    local answer
    printf '%s\n\n' "$1" >&2
    read -r -p "Type u + Enter to update assets, or just Enter to stop: " answer
    [ "$answer" = "u" ] && echo update || echo stop
  else
    echo none
  fi
}

# Re-point the venv at the bundled interpreter (the folder may have been moved)
CFG="$RES/venv/pyvenv.cfg"
{ printf 'home = %s\n' "$RES/python/bin"; grep -v -E '^(home|executable|command)[[:space:]]*=' "$CFG"; } > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"

IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
[ -n "$IP" ] || IP="$(hostname -I 2>/dev/null | awk '{print $1}')"

if ! "$PY" "$SCRAPER" --check >/dev/null 2>&1 \
  && confirm "Game assets haven't been downloaded yet. Download them now? This can take a while."; then
  download_assets
fi

cleanup() { [ -f "$RUN/php-fpm.pid" ] && kill "$(cat "$RUN/php-fpm.pid")" 2>/dev/null; }
trap cleanup EXIT
trap 'exit 0' TERM INT HUP

"$RES/php/php-fpm" -p "$RES" -y "$RES/php/php-fpm.conf" -c "$RES/php/php.ini" \
  || { msg "PHP-FPM failed to start (is port 9123 in use?). See $RUN/php-fpm.log"; exit 1; }

HELPER="$RES/bin/privileged.sh"
ARGS=("$$" "$(id -un)" "$IP")
if [ "$(id -u)" -eq 0 ]; then
  "$HELPER" "${ARGS[@]}" >/dev/null 2>&1 &
elif [ -t 0 ] && command -v sudo >/dev/null; then
  echo "Liberated needs root to bind DNS (53) and web (80/443) ports."
  sudo -v || exit 1
  sudo -n "$HELPER" "${ARGS[@]}" >/dev/null 2>&1 &
elif command -v pkexec >/dev/null; then
  pkexec "$HELPER" "${ARGS[@]}" >/dev/null 2>&1 &
else
  msg "Root access is required. Run Liberated from a terminal so sudo can prompt for your password."
  exit 1
fi
ELEVATED_PID=$!

# Wait for the helper to report in (or for the auth prompt to be cancelled)
for _ in $(seq 1 240); do
  [ -f "$RUN/helper.status" ] && break
  kill -0 "$ELEVATED_PID" 2>/dev/null || break
  sleep 0.5
done
STATUS="$(cat "$RUN/helper.status" 2>/dev/null || echo "Authorization was cancelled or failed.")"
[ "$STATUS" = "ok" ] || { msg "$STATUS"; exit 1; }

TEXT="Liberated is running.

Set your device DNS to: ${IP:-unknown}

Logs: resources/run and resources/web/logs"
while :; do
  case "$(menu "$TEXT")" in
    update) download_assets ;;
    stop) break ;;
    *) while :; do sleep 3600; done ;;   # no UI available: run until killed
  esac
done
EOF

# Initial desktop entry; the launcher rewrites it on each run
cat > "$OUT/Liberated.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Liberated
Comment=Liberated server (DNS + web)
Exec="$OUT/Liberated"
Icon=$RES/icon.png
Terminal=false
Categories=Network;
EOF

chmod +x "$OUT/Liberated" "$OUT/Liberated.desktop" "$RES/bin/privileged.sh" "$RES/bin/nginx"

echo
echo "==> Built: $OUT"
du -sh "$OUT" | awk '{print "    Size: "$1}'
