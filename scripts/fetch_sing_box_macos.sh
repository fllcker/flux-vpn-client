#!/usr/bin/env bash
# Downloads the pinned sing-box macOS release into assets/sing-box-macos/.
# Mirrors fetch_sing_box.ps1 (Windows) — see assets/sing-box/SOURCE.md. Meant
# to run on an actual Mac; not exercised by CI yet (see fetch_xray_macos.sh
# for why).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest_dir="$repo_root/assets/sing-box-macos"
tmp_tar="$(mktemp -t sing-box-macos.XXXXXX.tar.gz)"
tmp_extract="$(mktemp -d -t sing-box-macos-extract.XXXXXX)"

case "$(uname -m)" in
  arm64) arch="arm64" ;;
  x86_64) arch="amd64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

source "$repo_root/scripts/core_versions.env"
asset_name="sing-box-${SING_BOX_VERSION#v}-darwin-$arch.tar.gz"
download_url="https://github.com/SagerNet/sing-box/releases/download/$SING_BOX_VERSION/$asset_name"

echo "Downloading sing-box ($download_url)..."
curl -fsSL "$download_url" -o "$tmp_tar"

mkdir -p "$dest_dir"
tar -xzf "$tmp_tar" -C "$tmp_extract"
inner_dir="$(find "$tmp_extract" -mindepth 1 -maxdepth 1 -type d | head -n1)"
cp "$inner_dir/sing-box" "$dest_dir/"
cp "$inner_dir/LICENSE" "$dest_dir/LICENSE"
chmod +x "$dest_dir/sing-box"
rm -rf "$tmp_tar" "$tmp_extract"

echo "sing-box extracted to $dest_dir"
