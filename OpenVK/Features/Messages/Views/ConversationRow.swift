//
//  ConversationRow.swift
//  OpenVK for iOS
//

import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation

    private var messagePreview: String {
        guard !conversation.lastMessage.isEmpty else {
            return "Нет сообщений"
        }

        guard let author = conversation.lastMessageAuthorName else {
            return conversation.lastMessage
        }

        return author + ": " + conversation.lastMessage
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

                    Text(conversation.updatedAt.openvkFormatted())
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Text(messagePreview)
                        .font(.system(size: 14))
                        .foregroundColor(conversation.unreadCount > 0 ? .primary : .secondary)
                        .fontWeight(conversation.unreadCount > 0 ? .medium : .regular)
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
    }
}
