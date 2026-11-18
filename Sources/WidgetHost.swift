import AppKit

@main
@MainActor
final class WidgetHost: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var panel: ChatPanelController?
    private var statusItem: NSStatusItem?
    private var hidePanelItem: NSMenuItem?

    static func main() {
        let app = NSApplication.shared
        let delegate = WidgetHost()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenuBarItem()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel == nil else { return }
            self.open(.openChatGPT)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        open(.openChatGPT)
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        panel?.refreshFocusAppearance()
    }

    func applicationDidResignActive(_ notification: Notification) {
        panel?.refreshFocusAppearance()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let action = urls.compactMap(WidgetAction.init(url:)).first {
            open(action, near: NSEvent.mouseLocation)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        hidePanelItem?.isEnabled = panel?.window?.isVisible == true
    }

    private func configureMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(named: "ChatGPTMenuTemplate")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "ChatGPT Widget"
        item.button?.setAccessibilityLabel("ChatGPT Widget")
        if image == nil {
            item.button?.title = "GPT"
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        menu.addItem(withTitle: "Open ChatGPT Widget", action: #selector(showPanel), keyEquivalent: "").target = self
        let hide = menu.addItem(withTitle: "Hide Panel", action: #selector(hidePanel), keyEquivalent: "")
        hide.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ChatGPT Widget", action: #selector(quit), keyEquivalent: "").target = self
        hidePanelItem = hide
        item.menu = menu
        statusItem = item
    }

    @objc private func showPanel() {
        open(.openChatGPT)
    }

    @objc private func hidePanel() {
        panel?.collapse()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func open(_ action: WidgetAction, near pointer: NSPoint? = nil) {
        let panel = self.panel ?? ChatPanelController()
        self.panel = panel
        panel.present(startNewChat: action == .newChat, near: pointer)
    }
}
