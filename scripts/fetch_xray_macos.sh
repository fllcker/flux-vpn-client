#!/usr/bin/env bash
# Downloads the pinned Xray-core macOS release into assets/xray-macos/.
# Mirrors fetch_xray.ps1 (Windows) — see assets/xray/SOURCE.md. Meant to run
# on an actual Mac (uses `uname -m` to pick arm64/x86_64); not exercised by
# CI yet, see PLAN.md/scripts note on the macOS build job being deferred
# until there's a Developer account to sign against.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest_dir="$repo_root/assets/xray-macos"
tmp_zip="$(mktemp -t xray-macos.XXXXXX.zip)"

case "$(uname -m)" in
  arm64) asset_name="Xray-macos-arm64-v8a.zip" ;;
  x86_64) asset_name="Xray-macos-64.zip" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

source "$repo_root/scripts/core_versions.env"
download_url="https://github.com/XTLS/Xray-core/releases/download/$XRAY_VERSION/$asset_name"

echo "Downloading Xray-core ($asset_name)..."
curl -fsSL "$download_url" -o "$tmp_zip"

mkdir -p "$dest_dir"
unzip -o "$tmp_zip" -d "$dest_dir" >/dev/null
rm -f "$tmp_zip"

# geoip.dat/geosite.dat скачиваются в рантайме (см. fetch_xray.ps1) — не
# нужны в бандле.
rm -f "$dest_dir/geoip.dat" "$dest_dir/geosite.dat"

chmod +x "$dest_dir/xray"
echo "Xray-core extracted to $dest_dir"
