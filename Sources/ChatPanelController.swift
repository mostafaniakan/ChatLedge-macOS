import AppKit
import WebKit

@MainActor
final class ChatPanelController: NSWindowController, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate,
                                 WKDownloadDelegate {
    private static let chatURL = URL(string: "https://chatgpt.com/")!
    private static let pinPreference = "ChatPanelPinned"
    private static let frameName = "CompactChatPanel"

    private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let darkBackground = NSView()
    private let returnToChatButton = ChatPanelButton()
    private let status = NSTextField(wrappingLabelWithString: "Loading ChatGPT…")
    private var idle = ChatPanelIdle()
    private var idleTimer: Timer?
    private var hasRequestedChat = false
    private var hasPanelPosition = false
    private var pinned = UserDefaults.standard.object(forKey: pinPreference) as? Bool ?? true

    init() {
        let panel = ChatPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)

        panel.title = "ChatLedge"
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.contentMinSize = NSSize(width: 320, height: 300)
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.onInteraction = { [weak self] in self?.idle.recordInteraction() }
        panel.onContextMenu = { [weak self] event in self?.showCardMenu(with: event) }
        panel.onCollapse = { [weak self] in self?.collapse() }
        hasPanelPosition = panel.setFrameUsingName(Self.frameName)
        if !hasPanelPosition {
            panel.center()
        }
        panel.setFrameAutosaveName(Self.frameName)
        configureWebView(in: panel)
        applyPin()
        refreshFocusAppearance()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ChatPanelController is created in code")
    }

    func present(startNewChat: Bool, near pointer: NSPoint? = nil) {
        if startNewChat || !hasRequestedChat {
            loadChat()
        }
        if !hasPanelPosition {
            if let pointer {
                positionPanel(near: pointer)
            }
            hasPanelPosition = true
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
        idle.recordInteraction()
        scheduleIdleCheck(after: ChatPanelIdle.interval)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        collapse()
        return false
    }

    func windowDidBecomeKey(_ notification: Notification) {
        refreshFocusAppearance()
    }

    func windowDidResignKey(_ notification: Notification) {
        refreshFocusAppearance()
    }

    func refreshFocusAppearance() {
        let focused = window?.isKeyWindow == true && NSApplication.shared.isActive
        darkBackground.alphaValue = focused ? 1 : 0
        // Blend the opaque web page with the backdrop while preserving its visible content and state.
        webView.alphaValue = focused ? 1 : 0.72
    }

    private func positionPanel(near pointer: NSPoint) {
        guard let window, let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) else {
            return
        }
        let area = screen.visibleFrame
        let frame = window.frame
        let x = max(area.minX, min(pointer.x - 80, area.maxX - frame.width))
        let y = max(area.minY, min(pointer.y - frame.height + 50, area.maxY - frame.height))
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc func collapse() {
        idleTimer?.invalidate()
        idleTimer = nil
        idle.stop()
        window?.orderOut(nil)
    }

    private func scheduleIdleCheck(after interval: TimeInterval) {
        idleTimer?.invalidate()
        let timer = Timer(timeInterval: interval, target: self, selector: #selector(idleTimerFired),
                          userInfo: nil, repeats: false)
        idleTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func didWake(_ notification: Notification) {
        checkIdle()
    }

    @objc private func idleTimerFired(_ timer: Timer) {
        checkIdle()
    }

    private func checkIdle() {
        guard let remaining = idle.remaining(), window?.isVisible == true else { return }
        if remaining > 0 {
            scheduleIdleCheck(after: remaining)
        } else if window?.attachedSheet != nil ||
                    webView.microphoneCaptureState == .active || webView.cameraCaptureState == .active {
            scheduleIdleCheck(after: 60)
        } else {
            collapse()
        }
    }

    private func configureWebView(in panel: NSWindow) {
        let content = NSVisualEffectView()
        content.material = .hudWindow
        content.blendingMode = .behindWindow
        content.state = .active
        content.wantsLayer = true
        content.layer?.cornerRadius = 28
        content.layer?.cornerCurve = .continuous
        content.layer?.masksToBounds = true
        content.layer?.borderWidth = 0.75
        content.layer?.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor
        panel.contentView = content

        darkBackground.wantsLayer = true
        darkBackground.layer?.backgroundColor = NSColor(white: 0.11, alpha: 1).cgColor
        darkBackground.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(darkBackground)

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.pageZoom = 0.88
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(webView)

        let dragArea = ChatPanelDragArea()
        dragArea.translatesAutoresizingMaskIntoConstraints = false
        dragArea.toolTip = "Move ChatLedge"
        content.addSubview(dragArea)

        let closeImage = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: "Close ChatLedge"
        ) ?? NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Close ChatLedge")!
        let closeButton = ChatPanelButton(image: closeImage, target: self, action: #selector(collapse))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isBordered = false
        closeButton.toolTip = "Close ChatLedge"
        closeButton.setAccessibilityLabel("Close ChatLedge")
        content.addSubview(closeButton)

        returnToChatButton.title = "Back to ChatGPT"
        returnToChatButton.bezelStyle = .recessed
        returnToChatButton.target = self
        returnToChatButton.action = #selector(returnToChat)
        returnToChatButton.translatesAutoresizingMaskIntoConstraints = false
        returnToChatButton.isHidden = true
        content.addSubview(returnToChatButton)

        status.alignment = .center
        status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(status)
        NSLayoutConstraint.activate([
            darkBackground.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            darkBackground.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            darkBackground.topAnchor.constraint(equalTo: content.topAnchor),
            darkBackground.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.topAnchor.constraint(equalTo: content.topAnchor),
            webView.bottomAnchor.constraint(equalTo: dragArea.topAnchor),
            dragArea.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            dragArea.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            dragArea.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            dragArea.heightAnchor.constraint(equalToConstant: 34),
            closeButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -21),
            closeButton.centerYAnchor.constraint(equalTo: dragArea.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),
            returnToChatButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            returnToChatButton.centerYAnchor.constraint(equalTo: dragArea.centerYAnchor),
            status.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            status.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            status.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -48)
        ])
        panel.initialFirstResponder = webView
    }

    private func showCardMenu(with event: NSEvent) {
        guard let content = window?.contentView else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        let back = menu.addItem(withTitle: "Back", action: #selector(goBack), keyEquivalent: "")
        back.target = self
        back.isEnabled = webView.canGoBack
        menu.addItem(withTitle: "Reload", action: #selector(reload), keyEquivalent: "").target = self
        let pasteAction = #selector(NSText.paste(_:))
        let paste = menu.addItem(withTitle: "Paste", action: pasteAction, keyEquivalent: "v")
        paste.isEnabled = NSApplication.shared.target(forAction: pasteAction) != nil
        menu.addItem(.separator())
        let pin = menu.addItem(withTitle: "Keep on Top", action: #selector(togglePin), keyEquivalent: "")
        pin.target = self
        pin.state = pinned ? .on : .off
        menu.addItem(withTitle: "Collapse to Widget", action: #selector(collapse), keyEquivalent: "w").target = self
        NSMenu.popUpContextMenu(menu, with: event, for: content)
    }

    private func applyPin() {
        window?.level = pinned ? .floating : .normal
    }

    private func loadChat() {
        hasRequestedChat = true
        webView.load(URLRequest(url: Self.chatURL))
    }

    @objc private func goBack() {
        webView.goBack()
    }

    @objc private func returnToChat() {
        if let previousChat = webView.backForwardList.backList.last(where: { isChatURL($0.url) }),
           webView.go(to: previousChat) != nil {
            return
        }
        loadChat()
    }

    @objc private func reload() {
        status.isHidden = true
        if webView.url == nil {
            loadChat()
        } else {
            webView.reload()
        }
    }

    @objc private func togglePin() {
        pinned.toggle()
        UserDefaults.standard.set(pinned, forKey: Self.pinPreference)
        applyPin()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        status.isHidden = true
        if let url = webView.url {
            returnToChatButton.isHidden = isChatURL(url)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        showNavigationFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showNavigationFailure(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        status.stringValue = "The page stopped responding. Control-click the card and select Reload."
        status.isHidden = false
    }

    private func showNavigationFailure(_ error: Error) {
        let failure = error as NSError
        if failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled { return }
        status.stringValue = "Couldn’t load the page. Control-click the card and select Reload."
        status.isHidden = false
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        switch action.request.url?.scheme {
        case "https", "about", "blob":
            decisionHandler(action.shouldPerformDownload ? .download : .allow)
        default:
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.request.url?.scheme == "https" {
            webView.load(action.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        guard let window, isChatOrigin(frame.securityOrigin) else {
            completionHandler(nil)
            return
        }
        let picker = NSOpenPanel()
        picker.canChooseDirectories = parameters.allowsDirectories
        picker.allowsMultipleSelection = parameters.allowsMultipleSelection
        picker.beginSheetModal(for: window) { result in
            completionHandler(result == .OK ? picker.urls : nil)
        }
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(isChatOrigin(origin) ? .prompt : .deny)
    }

    private func isChatOrigin(_ origin: WKSecurityOrigin) -> Bool {
        origin.protocol == "https" && isChatHost(origin.host)
    }

    private func isChatURL(_ url: URL) -> Bool {
        url.scheme == "https" && isChatHost(url.host ?? "")
    }

    private func isChatHost(_ host: String) -> Bool {
        host == "chatgpt.com" || host.hasSuffix(".chatgpt.com")
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        guard let window else {
            completionHandler(nil)
            return
        }
        let picker = NSSavePanel()
        picker.nameFieldStringValue = suggestedFilename
        picker.beginSheetModal(for: window) { result in
            completionHandler(result == .OK ? picker.url : nil)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let failure = error as NSError
        guard let window, !(failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled) else {
            return
        }
        let alert = NSAlert()
        alert.messageText = "Couldn’t save the file"
        alert.informativeText = failure.localizedDescription
        alert.beginSheetModal(for: window)
    }
}

@MainActor
private final class ChatPanelButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
private final class ChatPanelDragArea: NSView {
    private var dragStart: (pointer: NSPoint, origin: NSPoint)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let grip = NSRect(x: bounds.midX - 15, y: bounds.midY - 1.5, width: 30, height: 3)
        NSColor.white.withAlphaComponent(0.42).setFill()
        NSBezierPath(roundedRect: grip, xRadius: 1.5, yRadius: 1.5).fill()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStart = (window.convertPoint(toScreen: event.locationInWindow), window.frame.origin)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragStart else { return }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        window.setFrameOrigin(NSPoint(
            x: dragStart.origin.x + point.x - dragStart.pointer.x,
            y: dragStart.origin.y + point.y - dragStart.pointer.y
        ))
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }
}

@MainActor
private final class ChatPanelWindow: NSWindow {
    var onInteraction: (() -> Void)?
    var onContextMenu: ((NSEvent) -> Void)?
    var onCollapse: (() -> Void)?
    private var resizeStart: (pointer: NSPoint, frame: NSRect)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            onInteraction?()
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if modifiers.isEmpty && event.charactersIgnoringModifiers == "\u{1B}" && attachedSheet == nil {
                onCollapse?()
                return
            }
            if modifiers == .command && attachedSheet == nil {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "w":
                    onCollapse?()
                    return
                case "v":
                    if NSApplication.shared.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) {
                        return
                    }
                default:
                    break
                }
            }
        case .leftMouseDown, .rightMouseDown:
            onInteraction?()
            if attachedSheet == nil && handleCardClick(event) { return }
        case .leftMouseDragged:
            if let resizeStart {
                resizeCard(from: resizeStart, to: NSEvent.mouseLocation)
                return
            }
        case .leftMouseUp:
            if resizeStart != nil {
                resizeStart = nil
                onInteraction?()
                return
            }
        case .otherMouseDown, .scrollWheel, .magnify, .swipe:
            onInteraction?()
        default:
            break
        }
        super.sendEvent(event)
    }

    private func handleCardClick(_ event: NSEvent) -> Bool {
        let point = event.locationInWindow
        let inset = 8.0
        let edge = point.x < inset || point.x > frame.width - inset ||
            point.y < inset || point.y > frame.height - inset
        if event.modifierFlags.contains(.control) || (event.type == .rightMouseDown && edge) {
            onContextMenu?(event)
            return true
        }
        guard event.type == .leftMouseDown else { return false }
        if point.x > frame.width - 20 && point.y < 20 {
            resizeStart = (NSEvent.mouseLocation, frame)
            return true
        }
        if point.y > frame.height - inset {
            performDrag(with: event)
            return true
        }
        return false
    }

    private func resizeCard(from start: (pointer: NSPoint, frame: NSRect), to pointer: NSPoint) {
        let area = screen?.visibleFrame ?? start.frame
        let maxWidth = max(contentMinSize.width, area.maxX - start.frame.minX)
        let maxHeight = max(contentMinSize.height, start.frame.maxY - area.minY)
        let width = min(maxWidth, max(contentMinSize.width, start.frame.width + pointer.x - start.pointer.x))
        let height = min(maxHeight, max(contentMinSize.height, start.frame.height - pointer.y + start.pointer.y))
        setFrame(NSRect(x: start.frame.minX, y: start.frame.maxY - height, width: width, height: height),
                 display: true)
    }
}
