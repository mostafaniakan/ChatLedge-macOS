#!/bin/bash
set -euo pipefail

fail() {
    printf 'ChatLedge: %s\n' "$1" >&2
    exit 1
}

[[ "$(uname -s)" == Darwin ]] || fail "This installer runs on macOS only."
macos_version="$(sw_vers -productVersion)"
(( ${macos_version%%.*} >= 14 )) || fail "macOS 14 Sonoma or later is required."

app_dir="/Applications"
app_path="$app_dir/ChatLedge.app"
[[ ! -e "$app_path" && ! -L "$app_path" ]] ||
    fail "ChatLedge is already installed. Quit it and move the existing app out of Applications before reinstalling."
[[ -w "$app_dir" ]] || fail "You need write access to /Applications. Run the installer from a Mac administrator account."

if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --sdk macosx --find swiftc >/dev/null 2>&1; then
    fail "Run 'xcode-select --install' to install the Command Line Tools, then run this installer again."
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/chatledge-install.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

printf 'Downloading ChatLedge…\n'
git clone --quiet --depth 1 --branch main https://github.com/mostafaniakan/ChatLedge-macOS.git "$work_dir/source"

printf 'Building ChatLedge…\n'
archive="$(/bin/bash "$work_dir/source/build.sh")"
ditto -x -k "$archive" "$work_dir/app"
built_app="$work_dir/app/ChatLedge.app"
codesign --verify --deep --strict "$built_app"

mv -n "$built_app" "$app_dir/"
[[ ! -e "$built_app" ]] || fail "ChatLedge appeared in Applications during installation. The existing app was kept."
printf 'Installed %s\nOpen ChatLedge once before adding its desktop widget.\n' "$app_path"
