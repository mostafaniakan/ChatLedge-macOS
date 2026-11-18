# ChatGPT Widget for macOS

Open ChatGPT from a desktop widget in a compact floating panel. The panel displays [chatgpt.com](https://chatgpt.com/) and keeps its place on your desktop between launches.

This is an independent macOS project built with AppKit, SwiftUI, WidgetKit, and WebKit.

## Requirements

- macOS 14 Sonoma or later
- Xcode or Apple Command Line Tools with Swift and the macOS SDK
- Internet access to use ChatGPT

## Build and install

Run this command from the project directory.

```sh
bash build.sh
```

The script builds for your Mac’s architecture and creates `build/ChatGPT Widget.zip`. By default, it uses local ad hoc signing. To use a signing identity from your Keychain, set `WIDGET_SIGNING_IDENTITY` before running the script.

1. Open the ZIP in Finder and move **ChatGPT Widget.app** to **Applications**. Close an older copy before replacing it.
2. Open the app once so macOS can register its WidgetKit extension.
3. Control-click the desktop, choose **Edit Widgets**, and search for **ChatGPT Widget**.
4. Add the **Small** widget for a square launcher or **Medium** for separate **New chat** and **Open ChatGPT** shortcuts.

## Use the panel

- Click the desktop widget to open the panel. Its starting size is 340 × 420 points.
- Drag the handle at the bottom to move it, or drag the lower-right corner to resize it. The app remembers the size and position.
- Click the collapse icon or press **⌘W** to hide the panel. It also hides after 30 minutes of inactivity. Click the widget to return to the page you were on.
- Control-click the panel for **Keep on Top**, **Reload**, and other panel actions. The panel turns translucent when it loses focus.
- Use the double-bubble icon in the menu bar to open or hide the panel, or choose **Quit ChatGPT Widget** to exit.

## Sign in

Use **Log in** on the ChatGPT page inside the panel. WebKit keeps that session on your Mac between launches. Available sign-in methods depend on the provider. Google restricts OAuth sign-in in embedded web views. [Google’s desktop OAuth documentation](https://developers.google.com/identity/protocols/oauth2/native-app)

The desktop card uses WidgetKit for its shortcuts. Typing and web browsing happen in the panel. [Apple’s WidgetKit documentation](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
