#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

configuration="${1:-release}"
product="DawnSend"
dist_dir="$root/dist"
app_dir="$dist_dir/${product}.app"
binary_name="$product"

echo "==> Building ${product} (${configuration})"
swift build --package-path "$root" -c "$configuration" --product "$product"

bin_dir="$(swift build --package-path "$root" -c "$configuration" --product "$product" --show-bin-path)"
binary="$bin_dir/$binary_name"

if [[ ! -f "$binary" ]]; then
  echo "error: expected binary at $binary" >&2
  exit 1
fi

echo "==> Packaging ${product}.app"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"

cp "$binary" "$app_dir/Contents/MacOS/$binary_name"
chmod +x "$app_dir/Contents/MacOS/$binary_name"
cp "$root/Resources/Info.plist" "$app_dir/Contents/Info.plist"
printf 'APPL????' > "$app_dir/Contents/PkgInfo"

plutil -lint "$app_dir/Contents/Info.plist" >/dev/null

identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_dir/Contents/Info.plist")"
display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$app_dir/Contents/Info.plist")"
ui_element="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$app_dir/Contents/Info.plist")"

if [[ "$identifier" != "app.dawnsend" ]]; then
  echo "error: CFBundleIdentifier is ${identifier}" >&2
  exit 1
fi
if [[ "$display_name" != "DawnSend" ]]; then
  echo "error: CFBundleDisplayName is ${display_name}" >&2
  exit 1
fi
if [[ "$ui_element" != "true" ]]; then
  echo "error: LSUIElement is ${ui_element} (Dock must stay hidden)" >&2
  exit 1
fi

if command -v codesign >/dev/null; then
  codesign --force --sign - --timestamp=none "$app_dir" >/dev/null
fi

echo "==> Built ${app_dir}"
