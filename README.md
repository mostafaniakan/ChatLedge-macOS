# ChatLedge

ChatLedge opens ChatGPT in a resizable floating panel from a macOS desktop widget. Click the square widget to open the panel, drag it beside the app you’re using, and collapse it when you’re done. Reopening the panel brings back the current page.

ChatLedge is an independent project built with AppKit, SwiftUI, WidgetKit, and WebKit. It loads the official [ChatGPT website](https://chatgpt.com/) and requires no API key.

## Requirements

- macOS 14 Sonoma or later. Tested on macOS 26 on Apple silicon.
- Xcode or Apple Command Line Tools with Swift and the macOS SDK
- Internet access to use ChatGPT

## Build from source

```sh
git clone https://github.com/mostafaniakan/ChatLedge-macOS.git
cd ChatLedge-macOS
bash build.sh
```

The script builds for your Mac’s architecture and creates `build/ChatLedge.zip`. It uses local ad hoc signing by default. For direct binary distribution, set `WIDGET_SIGNING_IDENTITY` to your Developer ID Application identity and [notarize the build with Apple](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Install the widget

1. Open the ZIP in Finder and move **ChatLedge.app** to **Applications**.
2. Open the app once so macOS can register its WidgetKit extension.
3. Control-click the desktop, choose **Edit Widgets**, and search for **ChatLedge**.
4. Add the **Small** widget for a square launcher or **Medium** for separate **New chat** and **Open ChatGPT** shortcuts.

When upgrading from a development build named **ChatGPT Widget.app**, quit that copy and move it to the Trash before installing **ChatLedge.app** to avoid duplicate widget registrations.

## Use the panel

- Click the desktop widget to open the panel. Its starting size is 340 × 420 points.
- Drag the handle at the bottom to move it, or drag the lower-right corner to resize it. The app remembers the size and position.
- Click the **×** button, or press **Escape** or **⌘W**, to hide the panel. It also hides after 30 minutes of inactivity. Click the widget to return to the page you were on.
- When another site opens in the panel, click **Back to ChatGPT** to return to ChatGPT.
- Control-click the panel for **Keep on Top**, **Reload**, and other panel actions. The panel turns translucent when it loses focus.
- Paste into the chat field with **⌘V** or Control-click the panel and choose **Paste**.
- Use the double-bubble icon in the menu bar to show or hide the panel, or choose **Quit ChatLedge** to exit.

## Sign-in and compatibility

Use **Log in** inside the panel. WebKit stores the website session on your Mac between launches. Your sign-in method and available ChatGPT features depend on your account and WebKit compatibility. Google restricts OAuth sign-in in embedded web views. [Google’s desktop OAuth documentation](https://developers.google.com/identity/protocols/oauth2/native-app)

The desktop card uses WidgetKit for its shortcuts. Typing and web browsing happen in the panel. [Apple’s WidgetKit documentation](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)

## License

[MIT](LICENSE)
