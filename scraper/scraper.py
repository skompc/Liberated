"""Downloads the game's asset bundles into web/html/contents/<platform>/custom/<lang>/.

Usage: scraper.py [--check] [html_dir]
  --check   exit 0 if assets are already downloaded, 1 otherwise
"""
import json
import os
import ssl
import sys
import urllib.request

HEADERS = {
    "User-Agent": "SEGA Web Client for D2SMTL 2018",
    "X-Unity-Version": "2021.3.23f1",
}

HERE = os.path.dirname(os.path.abspath(__file__))

try:
    import certifi
    SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    SSL_CONTEXT = ssl.create_default_context()


def get(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=120, context=SSL_CONTEXT) as resp:
        return resp.read()


def main():
    args = [a for a in sys.argv[1:] if a != "--check"]
    check_only = "--check" in sys.argv[1:]
    html_dir = args[0] if args else os.path.join(HERE, "..", "web", "html")

    with open(os.path.join(HERE, "scraper-config.json")) as f:
        cfg = json.load(f)

    dest = os.path.join(html_dir, "contents", cfg["platform"], "custom", cfg["lang_code"])
    ab_list_path = os.path.join(dest, "ab_list.txt")
    if check_only:
        return 0 if os.path.exists(ab_list_path) else 1

    init_url = (
        "https://d2r-sim.d2megaten.com/socialsv/common/GetUrl.do"
        f"?check_code={cfg['check_code']}&platform={cfg['platform_num']}"
        f"&lang={cfg['lang_num']}&bundle_id=com.sega.d2megaten.en&_tm_=1"
    )
    print("Fetching asset bundle info...", flush=True)
    info = json.loads(get(init_url))
    version = info["asset_bundle_version"]
    base_url = f"{info['asset_bundle_url']}{cfg['platform']}/{version}/{cfg['lang_code']}/"
    print(f"Asset bundle version: {version}", flush=True)

    os.makedirs(os.path.join(dest, "assets"), exist_ok=True)
    ab_list = get(base_url + "ab_list.txt").decode("utf-8")

    names = []
    for line in ab_list.replace("\t", "|").strip().split("\n")[1:]:
        name = line.strip().split("|")[0]
        if name and name != "[EOF]":
            names.append(name)

    total = len(names)
    for i, name in enumerate(names, 1):
        path = os.path.join(dest, "assets", name)
        if os.path.exists(path):
            print(f"[{i}/{total}] {name} (already downloaded)", flush=True)
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        data = get(base_url + "assets/" + name)
        # Write to a temp name first so an interrupted run never leaves a truncated file behind
        with open(path + ".part", "wb") as f:
            f.write(data)
        os.replace(path + ".part", path)
        print(f"[{i}/{total}] {name}", flush=True)

    with open(os.path.join(dest, "assets", "ab.txt"), "wb") as f:
        f.write(get(base_url + "assets/ab.txt"))

    # The server always reports bundle version "custom"; written last so --check only passes on a full download
    lines = ab_list.split("\n")
    lines[0] = "custom"
    with open(ab_list_path, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(lines))

    print("Done downloading all files!", flush=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as e:
        print(f"Error: {e}", flush=True)
        sys.exit(1)
