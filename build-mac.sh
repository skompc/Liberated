#!/bin/bash
# Builds a self-contained dist/Liberated.app (nginx + PHP 8 FPM + Python 3 venv w/ dnslib + site content).
# Everything lives inside the .app; deleting it removes everything. Requires Xcode Command Line Tools.
set -euo pipefail

NGINX_VERSION="1.26.2"
OPENSSL_VERSION="3.0.15"
PCRE2_VERSION="10.44"
ZLIB_VERSION="1.3.1"
PHP_VERSION="8.3.32"
PY_VERSION="3.12.7"
PY_RELEASE="20241016"

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/dist/Liberated.app"
RES="$APP/Contents/Resources"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

case "$(uname -m)" in
  arm64)  ARCH="aarch64" ;;
  x86_64) ARCH="x86_64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

for tool in cc make curl tar sips iconutil; do
  command -v "$tool" >/dev/null || { echo "Missing '$tool'. Run: xcode-select --install" >&2; exit 1; }
done

fetch() { echo "==> Downloading $1"; curl -fL --retry 3 -o "$2" "$1"; }
JOBS="$(sysctl -n hw.ncpu)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$RES"/{bin,php,dns,run} "$RES/web"/{conf,logs,temp}

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
fetch "https://dl.static-php.dev/static-php-cli/common/php-$PHP_VERSION-fpm-macos-$ARCH.tar.gz" php.tgz
mkdir php && tar -xzf php.tgz -C php
cp "$(find php -type f -name php-fpm | head -n1)" "$RES/php/php-fpm"
chmod +x "$RES/php/php-fpm"

# Reuse the project's php.ini; extensions are compiled into the static binary.
sed -E 's/^(extension|zend_extension|extension_dir)[[:space:]]*=/;&/' "$ROOT/php/php.ini" > "$RES/php/php.ini"

cat > "$RES/php/php-fpm.conf" <<'EOF'
; Relative paths resolve against the -p prefix (Contents/Resources)
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
fetch "https://github.com/astral-sh/python-build-standalone/releases/download/$PY_RELEASE/cpython-$PY_VERSION+$PY_RELEASE-$ARCH-apple-darwin-install_only.tar.gz" python.tgz
tar -xzf python.tgz -C "$RES"   # extracts to $RES/python

echo "==> Creating venv and installing dnslib"
"$RES/python/bin/python3" -m venv "$RES/venv"
PIP_DISABLE_PIP_VERSION_CHECK=1 "$RES/venv/bin/python3" -m pip install --no-cache-dir dnslib certifi

# Make the venv interpreter links relative so the .app can be moved
for link in "$RES"/venv/bin/python*; do
  if [ -L "$link" ] && [[ "$(readlink "$link")" == /* ]]; then
    ln -sfn "../../python/bin/python3" "$link"
  fi
done

cp "$ROOT/dnsserver.py" "$RES/dns/dnsserver.py"
mkdir -p "$RES/scraper"
cp "$ROOT/scraper/scraper.py" "$ROOT/scraper/scraper-config.json" "$RES/scraper/"

# ---------------------------------------------------------------- Site content + nginx config
echo "==> Copying site content"
ditto "$ROOT/web/html" "$RES/web/html"
cp "$ROOT/web/conf/fastcgi_params" "$RES/web/conf/"
ditto "$ROOT/web/conf/ssl" "$RES/web/conf/ssl"

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

# ---------------------------------------------------------------- Asset download progress window (JXA + AppKit)
cat > "$RES/bin/progress.js" <<'EOF'
// Usage: osascript -l JavaScript progress.js <progress-file>
// Shows a progress window fed by "done<TAB>total<TAB>message"; exits on Cancel or when the file says "EXIT".
ObjC.import('Cocoa');

var cancelled = false;

ObjC.registerSubclass({
    name: 'LiberatedCancelTarget',
    methods: {
        'cancel:': {
            types: ['void', ['id']],
            implementation: function (sender) { cancelled = true; }
        }
    }
});

function run(argv) {
    var path = argv[0];
    var app = $.NSApplication.sharedApplication;
    app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

    var win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
        $.NSMakeRect(0, 0, 480, 130), $.NSWindowStyleMaskTitled, $.NSBackingStoreBuffered, false);
    win.title = 'Liberated - Downloading game assets';
    win.center;

    var message = $.NSTextField.labelWithString('Starting...');
    message.frame = $.NSMakeRect(20, 92, 440, 18);
    message.lineBreakMode = $.NSLineBreakByTruncatingMiddle;

    var bar = $.NSProgressIndicator.alloc.initWithFrame($.NSMakeRect(20, 62, 440, 20));
    bar.indeterminate = true;
    bar.minValue = 0;
    bar.maxValue = 100;
    bar.startAnimation(null);

    var count = $.NSTextField.labelWithString('');
    count.frame = $.NSMakeRect(20, 20, 300, 18);

    var target = $.LiberatedCancelTarget.alloc.init;
    var cancel = $.NSButton.buttonWithTitleTargetAction('Cancel', target, 'cancel:');
    cancel.frame = $.NSMakeRect(370, 12, 90, 32);

    [message, bar, count, cancel].forEach(function (v) { win.contentView.addSubview(v); });
    win.makeKeyAndOrderFront(null);
    app.activateIgnoringOtherApps(true);

    while (!cancelled) {
        var ev = app.nextEventMatchingMaskUntilDateInModeDequeue(
            $.NSEventMaskAny, $.NSDate.dateWithTimeIntervalSinceNow(0.2), $.NSDefaultRunLoopMode, true);
        if (!ev.isNil()) app.sendEvent(ev);

        var s = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
        if (s.isNil()) continue;
        var parts = s.js.split('\t');
        if (parts[0] === 'EXIT') break;

        var done = Number(parts[0]), total = Number(parts[1]);
        if (total > 0) {
            if (bar.indeterminate) { bar.stopAnimation(null); bar.indeterminate = false; }
            bar.doubleValue = done * 100 / total;
            count.stringValue = done + ' / ' + total + ' files (' + Math.floor(done * 100 / total) + '%)';
        }
        message.stringValue = parts.slice(2).join('\t');
    }
    win.close;
}
EOF

# ---------------------------------------------------------------- App launcher
# macOS 10.14+ lets unprivileged processes bind ports <1024 on all interfaces, so no root is needed.
cat > "$APP/Contents/MacOS/Liberated" <<'EOF'
#!/bin/bash
set -u
RES="$(cd "$(dirname "$0")/../Resources" && pwd)"
RUN="$RES/run"

# Gatekeeper runs quarantined (downloaded) apps from a read-only random path; nothing can be written there
if [[ "$RES" == */AppTranslocation/* ]] || ! [ -w "$RES" ]; then
  osascript -e 'display dialog "Liberated can'"'"'t run from its current location because macOS opened it read-only (this happens to downloaded apps).

Fix: in Finder, move Liberated.app to another folder (e.g. Applications), then open it again.

Or run this in Terminal:
xattr -dr com.apple.quarantine /path/to/Liberated.app" buttons {"OK"} default button 1 with title "Liberated" with icon stop' >/dev/null 2>&1
  exit 1
fi

mkdir -p "$RUN" "$RES/web/logs" "$RES/web/temp"

alert() {
  osascript -e 'on run argv' -e 'display dialog (item 1 of argv) buttons {"OK"} default button 1 with title "Liberated" with icon stop' -e 'end run' "$1" >/dev/null 2>&1
}

info() {
  osascript -e 'on run argv' -e 'display dialog (item 1 of argv) buttons {"OK"} default button 1 with title "Liberated" with icon note' -e 'end run' "$1" >/dev/null 2>&1
}

# ask <message> <button1> <button2>: prints the button clicked
ask() {
  osascript -e 'on run argv' -e 'activate' \
    -e 'button returned of (display dialog (item 1 of argv) buttons {(item 2 of argv), (item 3 of argv)} default button 2 with title "Liberated")' \
    -e 'end run' "$@" 2>/dev/null
}

PY="$RES/venv/bin/python3"
SCRAPER="$RES/scraper/scraper.py"

download_assets() {
  local prog="$RUN/scraper.progress" pid ui rc cancelled=0
  rm -f "$prog"
  "$PY" -u "$SCRAPER" --progress "$prog" > "$RUN/scraper.log" 2>&1 &
  pid=$!
  osascript -l JavaScript "$RES/bin/progress.js" "$prog" >/dev/null 2>&1 &
  ui=$!
  # The progress window exits early only when the user clicks Cancel
  while kill -0 "$pid" 2>/dev/null; do
    if ! kill -0 "$ui" 2>/dev/null; then cancelled=1; kill "$pid" 2>/dev/null; break; fi
    sleep 0.3
  done
  wait "$pid"; rc=$?
  printf 'EXIT\t%s' "$rc" > "$prog"
  wait "$ui" 2>/dev/null
  rm -f "$prog" "$prog.tmp"
  if [ "$cancelled" -eq 1 ]; then
    info "Asset download cancelled. Files downloaded so far are kept."
  elif [ "$rc" -eq 0 ]; then
    info "Game assets downloaded."
  else
    alert "Asset download failed: $(tail -n 1 "$RUN/scraper.log") (see $RUN/scraper.log)"
  fi
}

# Re-point the venv at the bundled interpreter (the .app may have been moved)
CFG="$RES/venv/pyvenv.cfg"
{ printf 'home = %s\n' "$RES/python/bin"; grep -v -E '^(home|executable|command)[[:space:]]*=' "$CFG"; } > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"

IFACE="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
IP=""
[ -n "$IFACE" ] && IP="$(ipconfig getifaddr "$IFACE" 2>/dev/null || true)"

if ! "$PY" "$SCRAPER" --check >/dev/null 2>&1; then
  [ "$(ask "Game assets haven't been downloaded yet. Download them now? This can take a while." "Skip" "Download")" = "Download" ] \
    && download_assets
fi

nginx_ctl() { "$RES/bin/nginx" -p "$RES/web/" -e logs/error.log -c conf/nginx.conf "$@"; }

cleanup() {
  nginx_ctl -s quit 2>/dev/null
  [ -n "${DNS_PID:-}" ] && kill "$DNS_PID" 2>/dev/null
  [ -f "$RUN/php-fpm.pid" ] && kill "$(cat "$RUN/php-fpm.pid")" 2>/dev/null
}
trap cleanup EXIT
trap 'exit 0' TERM INT HUP

"$RES/php/php-fpm" -p "$RES" -y "$RES/php/php-fpm.conf" -c "$RES/php/php.ini" \
  || { alert "PHP-FPM failed to start (is port 9123 in use?). See $RUN/php-fpm.log"; exit 1; }

nginx_ctl >> "$RUN/nginx-start.log" 2>&1 \
  || { alert "nginx failed to start (are ports 80/443 in use?). See $RES/web/logs/error.log"; exit 1; }

PYTHONDONTWRITEBYTECODE=1 "$RES/venv/bin/python3" -u "$RES/dns/dnsserver.py" "$IP" >> "$RUN/dns.log" 2>&1 &
DNS_PID=$!
sleep 1
kill -0 "$DNS_PID" 2>/dev/null \
  || { alert "DNS server failed to start (is port 53 in use?). See $RUN/dns.log"; exit 1; }

# Block until the user clicks Stop; exiting runs cleanup
while :; do
  choice="$(osascript -e 'on run argv' -e 'activate' \
    -e 'button returned of (display dialog "Liberated is running." & return & return & "Set your device DNS to: " & (item 1 of argv) & return & return & "Logs: Liberated.app/Contents/Resources/run and web/logs" buttons {"Update Assets", "Stop"} default button "Stop" with title "Liberated")' \
    -e 'end run' "${IP:-unknown}" 2>/dev/null)"
  case "$choice" in
    Stop) break ;;
    "Update Assets") download_assets ;;
    *) sleep 1 ;;
  esac
done
EOF

# ---------------------------------------------------------------- App icon
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" "$ROOT/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$ROOT/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RES/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Liberated</string>
    <key>CFBundleDisplayName</key><string>Liberated</string>
    <key>CFBundleIdentifier</key><string>com.liberated.server</string>
    <key>CFBundleExecutable</key><string>Liberated</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

chmod +x "$APP/Contents/MacOS/Liberated" "$RES/bin/nginx"
xattr -cr "$APP" 2>/dev/null || true
touch "$APP"   # nudge Finder to pick up the icon

echo
echo "==> Built: $APP"
du -sh "$APP" | awk '{print "    Size: "$1}'
