//
//  ConversationRow.swift
//  OpenVK for iOS
//

import SwiftUI

struct ConversationRow: View {

    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            Avatar(user: conversation.peer, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(conversation.peer.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if conversation.peer.isOfficial == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.appAccent)
                    }
                    SupporterBadgeView(screenName: conversation.peer.username)
                }
                let prefix = conversation.lastMessageOutgoing ? "Вы: " : ""
                Text(prefix + conversation.lastMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            if conversation.unreadCount > 0 {
                Text("\(conversation.unreadCount)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.appAccent))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
