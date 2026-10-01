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

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist/Liberated-linux"
RES="$OUT/resources"
mkdir -p "$ROOT/build"
WORK="$(mktemp -d "$ROOT/build/linux.XXXXXX")"
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
sed -E 's/^(extension|zend_extension|extension_dir)[[:space:]]*=/;&/' "$ROOT/src/php/php.ini" > "$RES/php/php.ini"

cat > "$RES/php/php-fpm.conf" <<'EOF'
; Relative paths resolve against the -p prefix (resources/)
[global]
pid = run/php-fpm.pid
error_log = run/php-fpm.log
daemonize = yes

[www]
listen = 127.0.0.1:9123
security.limit_extensions = .php .do
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

cp "$ROOT/src/python/dnsserver.py" "$RES/dns/dnsserver.py"
cp "$ROOT/icon.png" "$RES/icon.png"
mkdir -p "$RES/scraper"
cp "$ROOT/src/python/scraper/scraper.py" "$ROOT/src/python/scraper/scraper-config.json" "$RES/scraper/"

# ---------------------------------------------------------------- Site content + nginx config
echo "==> Copying site content"
cp -a "$ROOT/src/web/html" "$RES/web/html"
cp "$ROOT/src/web/conf/fastcgi_params" "$RES/web/conf/"
cp -a "$ROOT/src/web/conf/ssl" "$RES/web/conf/ssl"

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
# Runs as root to manage nginx and DNS; PHP-FPM remains owned by the user.
LAUNCHER_PID="$1"
RUN_USER="$2"
IP="${3:-}"
RES="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$RES/run"
RUN_GROUP="$(id -gn "$RUN_USER")"
COMMAND="$RUN/privileged.command"
NGINX_STATUS="$RUN/nginx.status"
DNS_STATUS="$RUN/dns.status"
DNS_PID=""
export PYTHONDONTWRITEBYTECODE=1   # no root-owned __pycache__ inside the folder

nginx_ctl() { "$RES/bin/nginx" -p "$RES/web/" -e logs/error.log -c conf/nginx.conf "$@"; }
write_status() {
  printf '%s\n' "$2" > "$1.tmp"
  chown "$RUN_USER:$RUN_GROUP" "$1.tmp"
  mv "$1.tmp" "$1"
}

start_web() {
  nginx_ctl -g "user $RUN_USER $RUN_GROUP;" >> "$RUN/nginx-start.log" 2>&1 \
    && { write_status "$NGINX_STATUS" running; write_status "$RUN/web.status" running; } \
    || { write_status "$NGINX_STATUS" 'failed (see web/logs/error.log)'; write_status "$RUN/web.status" 'failed (see web/logs/error.log)'; }
}

stop_web() {
  nginx_ctl -s quit 2>/dev/null || true
  write_status "$NGINX_STATUS" stopped
  write_status "$RUN/web.status" stopped
}

start_dns() {
  [ -n "$DNS_PID" ] && kill -0 "$DNS_PID" 2>/dev/null && return
  "$RES/venv/bin/python3" -u "$RES/dns/dnsserver.py" "$IP" >/dev/null 2>> "$RUN/dns.log" &
  DNS_PID=$!
  sleep 1
  if kill -0 "$DNS_PID" 2>/dev/null; then
    write_status "$DNS_STATUS" running
  else
    DNS_PID=""
    write_status "$DNS_STATUS" 'failed (port 53 in use; see run/dns.log)'
  fi
}

stop_dns() {
  [ -n "$DNS_PID" ] && kill "$DNS_PID" 2>/dev/null || true
  DNS_PID=""
  write_status "$DNS_STATUS" stopped
}

cleanup() {
  stop_web
  stop_dns
  sleep 1
  chown -R "$RUN_USER:$RUN_GROUP" "$RES/web/logs" "$RES/web/temp" "$RUN" 2>/dev/null
}
trap cleanup EXIT
trap 'exit 0' TERM INT HUP

write_status "$NGINX_STATUS" stopped
write_status "$DNS_STATUS" stopped
echo ready > "$RUN/helper.status"
while kill -0 "$LAUNCHER_PID" 2>/dev/null; do
  case "$(cat "$COMMAND" 2>/dev/null || true)" in
    start-web) start_web; printf 'idle\n' > "$COMMAND" ;;
    stop-web) stop_web; printf 'idle\n' > "$COMMAND" ;;
    start-dns) start_dns; printf 'idle\n' > "$COMMAND" ;;
    stop-dns) stop_dns; printf 'idle\n' > "$COMMAND" ;;
    stop-all) stop_web; stop_dns; printf 'idle\n' > "$COMMAND" ;;
    quit) exit 0 ;;
  esac
  sleep 0.25
done
EOF

# ---------------------------------------------------------------- Launcher
cp "$ROOT/scripts/launcher-linux.py" "$RES/bin/launcher.py"
"$RES/python/bin/python3" -c 'import tkinter' || { echo "Bundled Python lacks tkinter" >&2; exit 1; }

cat > "$OUT/Liberated" <<'EOF'
#!/bin/bash
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
RES="$HERE/resources"
ICON="$RES/icon.png"

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
StartupWMClass=Liberated
DESKTOP
  chmod +x "$HERE/Liberated.desktop"
fi

exec "$RES/python/bin/python3" "$RES/bin/launcher.py" "$@"
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
StartupWMClass=Liberated
EOF

chmod +x "$OUT/Liberated" "$OUT/Liberated.desktop" "$RES/bin/privileged.sh" "$RES/bin/nginx"

echo
echo "==> Built: $OUT"
du -sh "$OUT" | awk '{print "    Size: "$1}'
