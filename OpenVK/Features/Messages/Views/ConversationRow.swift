//
//  ConversationRow.swift
//  OpenVK for iOS
//

import SwiftUI

struct ConversationRow: View {

    let conversation: Conversation
    var typingStatus: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Avatar(peer: conversation.peer, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 4) {
                    if conversation.peer.type == .chat {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Text(conversation.peer.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if conversation.peer.isOfficial == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.appAccent)
                    }

                    Spacer()

                    Text(formatDate(conversation.updatedAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    if let typing = typingStatus {
                        HStack(spacing: 4) {
                            TypingIndicatorDots()
                            Text(typing)
                                .font(.system(size: 14))
                                .foregroundColor(.appAccent)
                        }
                    } else {
                        if conversation.lastMessageOutgoing {
                            Text("Вы:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        Text(conversation.lastMessage.isEmpty ? "Нет сообщений" : conversation.lastMessage)
                            .font(.system(size: 14))
                            .foregroundColor(conversation.unreadCount > 0 && !conversation.lastMessageOutgoing ? .primary : .secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if conversation.isImportant {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }

                    if conversation.isMuted {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))
                    }

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(conversation.isMuted ? Color(.systemGray4) : Color.appAccent))
                    } else if conversation.lastMessageOutgoing {
                        let isRead = conversation.outRead >= conversation.lastMessageId && conversation.lastMessageId > 0
                        DoubleCheckmarksView(isRead: isRead, color: isRead ? .appAccent : Color(.systemGray3))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Вчера"
        } else if let days = calendar.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "E"
            return formatter.string(from: date).capitalized
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yy"
            return formatter.string(from: date)
        }
    }
}

struct DoubleCheckmarksView: View {
    let isRead: Bool
    var size: CGFloat = 11
    var color: Color = .appAccent

    var body: some View {
        HStack(spacing: -5) {
            Image(systemName: "checkmark")
                .font(.system(size: size, weight: .bold))
                .foregroundColor(color)
            if isRead {
                Image(systemName: "checkmark")
                    .font(.system(size: size, weight: .bold))
                    .foregroundColor(color)
            }
        }
    }
}

struct TypingIndicatorDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 3.5, height: 3.5)
                    .scaleEffect(animating ? 1.0 : 0.4)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}
