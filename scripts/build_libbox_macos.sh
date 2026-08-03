#!/usr/bin/env bash
# Собирает Libbox.xcframework (macOS) из исходников sing-box через
# `gomobile bind` — то же самое, чем пользуется официальный
# SagerNet/sing-box-for-apple, см. docs/internal/macos/ROADMAP.md.
#
# Не хранится в git — как и остальные внешние бинарники этого проекта
# (assets/xray-macos, assets/sing-box-macos), пересобирается локально.
# Требует Go + Xcode command line tools; НЕ требует платного Apple
# Developer-аккаунта (тот нужен только на подпись самого System Extension
# таргета, не на сборку самой библиотеки).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$repo_root/.build-tools"
sing_box_dir="$work_dir/sing-box"
# Версия должна совпадать (или быть близкой) с той, что фактически
# используется как CLI-бинарник — см. assets/sing-box-macos/SOURCE.md.
sing_box_ref="${SING_BOX_REF:-v1.13.15}"

mkdir -p "$work_dir"

echo "Installing sing-box's gomobile/gobind fork (v0.1.12)..."
go install -v github.com/sagernet/gomobile/cmd/gomobile@v0.1.12
go install -v github.com/sagernet/gomobile/cmd/gobind@v0.1.12
export PATH="$PATH:$(go env GOPATH)/bin"

if [ ! -d "$sing_box_dir" ]; then
  echo "Cloning sing-box ($sing_box_ref)..."
  git clone --depth 1 --branch "$sing_box_ref" https://github.com/SagerNet/sing-box.git "$sing_box_dir"
else
  echo "Reusing existing checkout at $sing_box_dir"
fi

cd "$sing_box_dir"
echo "Building Libbox.xcframework (macOS only, debug)..."
go run ./cmd/internal/build_libbox -target apple -platform macos -debug

dest="$repo_root/macos/Frameworks/Libbox.xcframework"
mkdir -p "$repo_root/macos/Frameworks"
rm -rf "$dest"
mv Libbox.xcframework "$dest"
echo "Libbox.xcframework placed at $dest"
