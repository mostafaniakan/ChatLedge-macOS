import SwiftUI
import WidgetKit

struct ChatEntry: TimelineEntry {
    let date: Date
}

struct ChatProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChatEntry { ChatEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (ChatEntry) -> Void) {
        completion(ChatEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChatEntry>) -> Void) {
        completion(Timeline(entries: [ChatEntry(date: .now)], policy: .never))
    }
}

struct ChatWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemSmall {
                VStack(spacing: 10) {
                    ChatBadge(size: 46)
                    Text("ChatGPT").font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .widgetURL(WidgetAction.openChatGPT.url)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isLink)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 9) {
                        ChatBadge()
                        Text("ChatGPT").font(.headline)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 5)
                    action("New chat", icon: "square.and.pencil", destination: .newChat)
                    Divider().padding(.leading, 25)
                    action("Open ChatGPT", icon: "arrow.up.right.square", destination: .openChatGPT)
                }
                .widgetURL(WidgetAction.openChatGPT.url)
            }
        }
        .unredacted()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(white: 0.23), Color(white: 0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .environment(\.colorScheme, .dark)
    }

    private func action(_ title: String, icon: String, destination: WidgetAction) -> some View {
        Link(destination: destination.url) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 17)
                    .accessibilityHidden(true)
                Text(title)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.medium))
            .frame(minHeight: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ChatWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ChatGPTShortcuts", provider: ChatProvider()) { _ in
            ChatWidgetView()
        }
        .configurationDisplayName("ChatGPT")
        .description("Open the floating ChatGPT panel from your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ChatWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChatWidget()
    }
}
