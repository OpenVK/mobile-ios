//
//  ConversationRow.swift
//  OpenVK for iOS
//

import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation
    let typingText: String?
    @State private var typingDots = 1

    init(conversation: Conversation, typingText: String? = nil) {
        self.conversation = conversation
        self.typingText = typingText
    }

    private var messagePreview: String {
        guard !conversation.lastMessage.isEmpty else {
            return "Нет сообщений"
        }

        let text = normalizedMessage(conversation.lastMessage)
        guard let author = conversation.lastMessageAuthorName else {
            return text
        }

        return author + ": " + text
    }

    private var unreadCountText: String {
        let count = conversation.unreadCount
        if count < 1_000 {
            return String(count)
        }

        if count >= 1_000_000 {
            return abbreviatedCount(count, divisor: 1_000_000, suffix: "М")
        }

        return abbreviatedCount(count, divisor: 1_000, suffix: "К")
    }

    private var dateText: String {
        if conversation.isChat {
            let minutes = max(0, Int(Date().timeIntervalSince(conversation.updatedAt) / 60))
            if minutes == 5 { return "5 минут назад" }
        }
        return conversation.updatedAt.openvkFormatted()
    }

    private func abbreviatedCount(_ count: Int, divisor: Int, suffix: String) -> String {
        let scaled = Int((Double(count) / Double(divisor) * 10).rounded())
        let whole = scaled / 10
        let decimal = scaled % 10
        let value = decimal == 0
            ? String(whole)
            : String(whole) + "." + String(decimal)
        return value + suffix
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Avatar(user: conversation.peer, size: 48)

                if conversation.peer.isOnline && !conversation.isChat {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(conversation.peer.displayName)
                        .font(.system(size: 15, weight: conversation.unreadCount > 0 ? .semibold : .regular))
                        .lineLimit(1)

                    if conversation.peer.isOfficial == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.appAccent)
                    }

                    Spacer(minLength: 4)

                        Text(dateText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Text(typingText.map { $0 + String(repeating: ".", count: typingDots) } ?? messagePreview)
                        .font(.system(size: 14))
                        .foregroundColor(typingText == nil && conversation.unreadCount > 0 ? .primary : .secondary)
                        .fontWeight(typingText == nil && conversation.unreadCount > 0 ? .medium : .regular)
                        .lineLimit(2)

                    if conversation.unreadCount > 0 {
                        Spacer(minLength: 4)
                        Text(unreadCountText)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Capsule().fill(Color.appAccent))
                    }
                }
            }
        }
        .padding(.vertical, 5)
        .onChange(of: typingText) { value in
            if value != nil { typingDots = 1 }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            guard typingText != nil else { return }
            typingDots = typingDots == 3 ? 1 : typingDots + 1
        }
    }

    private func normalizedMessage(_ value: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\[(?:id|club)\d+\|([^\]]+)\]"#) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: "$1")
    }
}
