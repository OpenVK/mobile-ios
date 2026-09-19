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
        let calendar = Calendar.current
        let now = Date()
        if calendar.isDateInToday(conversation.updatedAt) {
            return Self.timeFormatter.string(from: conversation.updatedAt)
        }

        let startOfToday = calendar.startOfDay(for: now)
        let startOfMessageDay = calendar.startOfDay(for: conversation.updatedAt)
        let daysAgo = calendar.dateComponents([.day], from: startOfMessageDay, to: startOfToday).day ?? 0
        if daysAgo < 7 {
            return Self.weekdayFormatter.string(from: conversation.updatedAt).capitalized
        }

        if calendar.component(.year, from: conversation.updatedAt) == calendar.component(.year, from: now) {
            return Self.dayMonthFormatter.string(from: conversation.updatedAt)
        }
        return Self.dayMonthYearFormatter.string(from: conversation.updatedAt)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM"
        return formatter
    }()

    private static let dayMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

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
                    if conversation.lastMessageOutgoing {
                        ConversationReadReceiptIcon(isRead: conversation.lastMessageReadState == 1)
                            .foregroundStyle(Color.appAccent)
                            .accessibilityLabel(conversation.lastMessageReadState == 1 ? "Прочитано" : "Не прочитано")
                    }
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

                    Spacer(minLength: 4)

                    if conversation.unreadCount > 0 {
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

private struct ConversationReadReceiptIcon: View {
    let isRead: Bool
    @State private var displaysSecondCheckmark = false

    var body: some View {
        ZStack {
            Image(systemName: "checkmark")
                .offset(x: displaysSecondCheckmark ? -2 : 0)
            Image(systemName: "checkmark")
                .opacity(displaysSecondCheckmark ? 1 : 0)
                .offset(x: displaysSecondCheckmark ? 2 : 0)
        }
        .font(.system(size: 8, weight: .semibold))
        .frame(width: 12, height: 8)
        .onAppear { displaysSecondCheckmark = isRead }
        .onChange(of: isRead) { isRead in
            withAnimation(.easeOut(duration: 0.2)) {
                displaysSecondCheckmark = isRead
            }
        }
    }
}
