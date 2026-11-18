import Foundation

enum WidgetAction: String {
    case newChat = "new-chat"
    case openChatGPT = "open-chatgpt"

    var url: URL {
        URL(string: "chatgpt-desktop-widget://\(rawValue)")!
    }

    init?(url: URL) {
        guard url.scheme == "chatgpt-desktop-widget", let host = url.host,
              let action = Self(rawValue: host), action.url == url else { return nil }
        self = action
    }
}
