#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
root="$PWD"
output="$root/build"
mkdir -p "$output"
staging="$(mktemp -d "$output/.staging.XXXXXX")"
trap 'rm -rf "$staging"' EXIT

name="ChatLedge.app"
app="$staging/$name"
widget="$app/Contents/PlugIns/ChatGPTShortcuts.appex"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$widget/Contents/MacOS"
mkdir -p "$widget/Contents/Resources"
cp Config/App-Info.plist "$app/Contents/Info.plist"
cp Config/Widget-Info.plist "$widget/Contents/Info.plist"
cp Assets/ChatWidget.icns "$app/Contents/Resources/ChatWidget.icns"
cp Assets/ChatWidget.icns "$widget/Contents/Resources/ChatWidget.icns"
cp Assets/ChatGPTMenuTemplate.png "Assets/ChatGPTMenuTemplate@2x.png" "$app/Contents/Resources/"
cp Assets/ChatGPTMenuTemplate.png "Assets/ChatGPTMenuTemplate@2x.png" "$widget/Contents/Resources/"

sdk="$(xcrun --sdk macosx --show-sdk-path)"
shared=(Sources/ChatBadge.swift Sources/WidgetLinks.swift)
architectures=(arm64 x86_64)

for architecture in "${architectures[@]}"; do
    swift_args=(
        -sdk "$sdk"
        -target "$architecture-apple-macosx14.0"
        -module-cache-path "$output/ModuleCache-$architecture"
        -O
        -parse-as-library
    )
    architecture_output="$staging/$architecture"
    mkdir -p "$architecture_output"

    xcrun swiftc "${swift_args[@]}" Sources/WidgetLinks.swift Sources/WidgetHost.swift \
        Sources/ChatPanelController.swift Sources/ChatPanelIdle.swift \
        -o "$architecture_output/ChatGPTWidget"
    xcrun swiftc "${swift_args[@]}" -application-extension "${shared[@]}" Sources/ChatWidget.swift \
        -Xlinker -e -Xlinker _NSExtensionMain \
        -o "$architecture_output/ChatGPTShortcuts"
done

lipo -create "$staging/arm64/ChatGPTWidget" "$staging/x86_64/ChatGPTWidget" -output "$app/Contents/MacOS/ChatGPTWidget"
lipo -create "$staging/arm64/ChatGPTShortcuts" "$staging/x86_64/ChatGPTShortcuts" -output "$widget/Contents/MacOS/ChatGPTShortcuts"

signing_identity="${WIDGET_SIGNING_IDENTITY:--}"
signing_args=(--force --sign "$signing_identity")
if [[ "$signing_identity" == "Developer ID Application:"* ]]; then
    signing_args+=(--timestamp --options runtime)
fi
codesign "${signing_args[@]}" --entitlements Config/Widget.entitlements "$widget"
codesign "${signing_args[@]}" --entitlements Config/App.entitlements "$app"
codesign --verify --deep --strict "$app"

# Keep the built copy archived so LaunchServices only sees the installed app.
archive="ChatLedge.zip"
ditto -c -k --keepParent "$app" "$staging/$archive"
mv -f "$staging/$archive" "$output/$archive"
printf '%s\n' "$output/$archive"
