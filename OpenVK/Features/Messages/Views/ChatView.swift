//
//  ChatView.swift
//  OpenVK for iOS
//

import SwiftUI
import UIKit

struct ChatView: View {

    let conversation: Conversation

    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel: ChatViewModel
    @State private var showProfile = false
    @State private var showChatDetails = false
    @State private var showDeleteAlert = false
    @State private var deleteMessageId: Int?
    @State private var deleteForAll = true
    @State private var showBatchDeleteConfirmation = false
    @State private var showStickerPicker = false
    @State private var selectedMedia: Attachment? = nil
    @State private var owningPost: Post? = nil
    @State private var fullscreenImageURL: URL? = nil
    @State private var showAttachmentActionSheet = false
    @State private var showScrollToBottom = false

    init(conversation: Conversation) {
        self.conversation = conversation
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            peer: conversation.peer
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let pinned = viewModel.pinnedMessage ?? conversation.chatSettings?.pinnedMessage {
                PinnedMessageBar(message: pinned) {
                    withAnimation {
                        viewModel.flashMessage(pinned.id)
                    }
                } onUnpin: {
                    viewModel.unpinCurrentMessage()
                }
                Divider()
            }

            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding(.vertical, 30)
                                    .rotationEffect(.degrees(180))
                            }

                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, msg in
                                messageRow(msg, index: index)
                            }

                            if viewModel.hasMore {
                                ProgressView()
                                    .padding(.vertical, 8)
                                    .rotationEffect(.degrees(180))
                                    .onAppear {
                                        viewModel.loadMore()
                                    }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .rotationEffect(.degrees(180))
                    .onChange(of: viewModel.scrollToMessageId) { targetId in
                        if let targetId = targetId {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                proxy.scrollTo(targetId, anchor: .center)
                            }
                            viewModel.scrollToMessageId = nil
                        }
                    }
                }

                if showScrollToBottom {
                    Button(action: {
                        if let firstId = viewModel.messages.first?.id {
                            viewModel.scrollToMessageId = firstId
                        }
                    }) {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.appAccent)
                            )
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            if let reply = viewModel.replyingToMessage {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.appAccent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(reply.senderName ?? "Ответ")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appAccent)
                        Text(reply.text.isEmpty ? "[Вложение]" : reply.text)
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: { viewModel.cancelReply() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.appAccent.opacity(0.08))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if viewModel.editingMessageId != nil {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.appAccent)
                    Text("Редактирование")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appAccent)
                    Spacer()
                    Button(action: { viewModel.cancelEditing() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.appAccent.opacity(0.08))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Divider()

            nativeBottomInputBar
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                leadingToolbarContent
            }
            ToolbarItem(placement: .principal) {
                principalToolbarContent
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                trailingToolbarContent
            }
        }
        .modifier(HideTabBarModifier())
        .onAppear {
            viewModel.load()
            hideTabBar()
        }
        .onDisappear(perform: showTabBar)
        .background(
            Group {
                if conversation.peer.type == .chat {
                    NavigationLink(
                        destination: ChatDetailsView(conversation: conversation),
                        isActive: $showChatDetails
                    ) {
                        EmptyView()
                    }
                    .hidden()
                } else if let u = conversation.peer.user {
                    NavigationLink(
                        destination: ProfileView(user: u, selectedMedia: $selectedMedia, owningPost: $owningPost),
                        isActive: $showProfile
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
        )
        .sheet(isPresented: $showStickerPicker) {
            StickerPickerView { sticker in
                showStickerPicker = false
                viewModel.sendSticker(sticker)
            }
        }
        .fullScreenCover(item: Binding(get: { fullscreenImageURL.map { IdentifiableURL(url: $0) } }, set: { fullscreenImageURL = $0?.url })) { item in
            FullscreenImageViewer(url: item.url) {
                fullscreenImageURL = nil
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Удалить сообщение?"),
                primaryButton: .destructive(Text("Удалить")) {
                    if let id = deleteMessageId {
                        viewModel.deleteMessage(id, deleteForAll: deleteForAll)
                    }
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
        .alert(isPresented: $showBatchDeleteConfirmation) {
            Alert(
                title: Text("Удалить выбранные сообщения?"),
                primaryButton: .destructive(Text("Удалить для всех")) {
                    viewModel.deleteSelected(deleteForAll: true)
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
        .actionSheet(isPresented: $showAttachmentActionSheet) {
            ActionSheet(
                title: Text("Прикрепить вложение"),
                buttons: [
                    .default(Text("Фото или видео"), action: {
                    }),
                    .default(Text("Файл / Документ"), action: {
                    }),
                    .cancel(Text("Отмена"))
                ]
            )
        }
    }

    @ViewBuilder
    private var leadingToolbarContent: some View {
        if viewModel.isSelecting {
            Button("Отмена") {
                viewModel.clearSelection()
            }
            .foregroundColor(.appAccent)
        }
    }

    @ViewBuilder
    private var principalToolbarContent: some View {
        if viewModel.isSelecting {
            Text("Выбрано: \(viewModel.selectedMessageIds.count)")
                .font(.system(size: 16, weight: .semibold))
        } else {
            Button(action: {
                if conversation.peer.type == .chat {
                    showChatDetails = true
                } else {
                    showProfile = true
                }
            }) {
                VStack(alignment: .center, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(conversation.peer.title)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if conversation.peer.isOfficial == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.appAccent)
                        }
                    }

                    if viewModel.isPeerTyping {
                        HStack(spacing: 3) {
                            TypingIndicatorDots()
                            Text("печатает...")
                                .font(.system(size: 11))
                                .foregroundColor(.appAccent)
                        }
                    } else if conversation.peer.type == .chat {
                        Text("\(conversation.peer.membersCount ?? 1) участников")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else if conversation.peer.isOnline == true {
                        HStack(spacing: 3) {
                            Text("в сети")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.appAccent)
                            if let platform = conversation.peer.onlinePlatform {
                                PlatformIconView(platform: platform, size: 10, color: .appAccent)
                            }
                        }
                    } else if let lastSeen = conversation.peer.lastSeen, !lastSeen.isEmpty {
                        HStack(spacing: 3) {
                            Text(lastSeen)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            if let platform = conversation.peer.onlinePlatform {
                                PlatformIconView(platform: platform, size: 10, color: Color(.secondaryLabel))
                            }
                        }
                    } else {
                        Text("был(а) недавно")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var trailingToolbarContent: some View {
        if viewModel.isSelecting {
            Button(action: { showBatchDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        } else {
            Button(action: {
                if conversation.peer.type == .chat {
                    showChatDetails = true
                } else {
                    showProfile = true
                }
            }) {
                Avatar(peer: conversation.peer, size: 34)
            }
        }
    }

    private var nativeBottomInputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button(action: { showAttachmentActionSheet = true }) {
                Image(systemName: "paperclip")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 36)
            }

            HStack(alignment: .center, spacing: 6) {
                TextField(
                    viewModel.editingMessageId != nil ? "Изменить..." : "Сообщение...",
                    text: $viewModel.draft
                )
                .font(.system(size: 16))
                .padding(.leading, 12)
                .padding(.vertical, 7)

                Button(action: { showStickerPicker = true }) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(18)

            let hasDraft = !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button(action: {
                if hasDraft {
                    if viewModel.editingMessageId != nil {
                        viewModel.saveEdit()
                    } else {
                        viewModel.send()
                    }
                } else {
                    HapticManager.impact(.light)
                }
            }) {
                Image(systemName: (hasDraft || viewModel.editingMessageId != nil) ? "arrow.up.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor((hasDraft || viewModel.editingMessageId != nil) ? .appAccent : .secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func messageRow(_ msg: Message, index: Int) -> some View {
        let clusterPos = viewModel.clusterPosition(for: index)
        let isGroup = conversation.peer.type == .chat
        let isHighlighted = viewModel.highlightedMessageId == msg.id

        VStack(spacing: 2) {
            HStack(alignment: .bottom, spacing: 6) {
                if msg.direction == .incoming {
                    Spacer(minLength: 4)
                }

                if viewModel.isSelecting {
                    MessageBubbleView(
                        message: msg,
                        clusterPosition: clusterPos,
                        isGroupChat: isGroup,
                        isSelected: viewModel.selectedMessageIds.contains(msg.id),
                        reaction: viewModel.messageReactions[msg.id],
                        onTap: { viewModel.toggleSelection(msg.id) },
                        onReplyTap: { replyId in
                            viewModel.flashMessage(replyId)
                        },
                        onImageTap: { url in
                            fullscreenImageURL = url
                        }
                    )
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: msg.direction == .outgoing ? .leading : .trailing)
                } else {
                    Menu {
                        Section("Быстрые реакции") {
                            Button("👍 Нравится") { viewModel.toggleReaction("👍", on: msg.id) }
                            Button("❤️ Сердце") { viewModel.toggleReaction("❤️", on: msg.id) }
                            Button("🔥 Огонь") { viewModel.toggleReaction("🔥", on: msg.id) }
                            Button("😂 Смех") { viewModel.toggleReaction("😂", on: msg.id) }
                            Button("😮 Удивление") { viewModel.toggleReaction("😮", on: msg.id) }
                            Button("😢 Грусть") { viewModel.toggleReaction("😢", on: msg.id) }
                            Button("🎉 Праздник") { viewModel.toggleReaction("🎉", on: msg.id) }
                        }

                        Section {
                            Button(action: { viewModel.startReply(to: msg) }) {
                                Label("Ответить", systemImage: "arrowshape.turn.up.left")
                            }

                            if !msg.text.isEmpty {
                                Button(action: {
                                    UIPasteboard.general.string = msg.text
                                    HapticManager.impact(.light)
                                }) {
                                    Label("Скопировать текст", systemImage: "doc.on.doc")
                                }
                            }

                            Button(action: { viewModel.pinMessage(msg) }) {
                                Label(msg.isPinned ? "Открепить" : "Закрепить", systemImage: msg.isPinned ? "pin.slash" : "pin")
                            }

                            Button(action: { viewModel.toggleImportant(msg) }) {
                                Label(msg.isImportant ? "Убрать из важных" : "В важное", systemImage: msg.isImportant ? "star.slash" : "star")
                            }

                            if msg.direction == .outgoing && msg.sticker == nil {
                                Button(action: { viewModel.startEditing(msg) }) {
                                    Label("Изменить", systemImage: "pencil")
                                }
                            }

                            Button(action: { viewModel.toggleSelection(msg.id) }) {
                                Label("Выбрать", systemImage: "checkmark.circle")
                            }

                            Button(role: .destructive, action: {
                                deleteMessageId = msg.id
                                deleteForAll = true
                                showDeleteAlert = true
                            }) {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    } label: {
                        MessageBubbleView(
                            message: msg,
                            clusterPosition: clusterPos,
                            isGroupChat: isGroup,
                            isSelected: false,
                            reaction: viewModel.messageReactions[msg.id],
                            onTap: {},
                            onReplyTap: { replyId in
                                viewModel.flashMessage(replyId)
                            },
                            onImageTap: { url in
                                fullscreenImageURL = url
                            }
                        )
                    } primaryAction: {
                    }
                    .buttonStyle(PlainButtonStyle())
                    .swipeToReply(isIncoming: msg.direction == .incoming) {
                        viewModel.startReply(to: msg)
                    }
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: msg.direction == .outgoing ? .leading : .trailing)
                    .background(
                        isHighlighted
                            ? RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appAccent.opacity(0.25))
                                .padding(-4)
                                .rotationEffect(.degrees(180))
                            : nil
                    )
                }

                if msg.direction == .incoming {
                    if isGroup {
                        if clusterPos == .single || clusterPos == .bottom {
                            Avatar(url: msg.senderAvatarURL, placeholderSystemName: "person.fill", size: 30)
                                .rotationEffect(.degrees(180))
                        } else {
                            Color.clear
                                .frame(width: 30, height: 30)
                        }
                    }
                } else {
                    Spacer(minLength: 4)
                }

                if viewModel.isSelecting {
                    Image(systemName: viewModel.selectedMessageIds.contains(msg.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(viewModel.selectedMessageIds.contains(msg.id) ? .appAccent : Color(.systemGray4))
                        .rotationEffect(.degrees(180))
                        .onTapGesture {
                            viewModel.toggleSelection(msg.id)
                        }
                        .padding(.leading, 6)
                }
            }
            .padding(.vertical, (clusterPos == .middle || clusterPos == .top) ? 1 : 3)
            .padding(.horizontal, 10)
            .isSelectingRowTap(isSelecting: viewModel.isSelecting) {
                viewModel.toggleSelection(msg.id)
            }

            if isLastMessageOfDay(at: index) {
                MessageDateBadge(date: msg.date)
                    .rotationEffect(.degrees(180))
            }
        }
    }

    private func isLastMessageOfDay(at index: Int) -> Bool {
        guard index < viewModel.messages.count else { return false }
        if index == viewModel.messages.count - 1 {
            return true
        }
        let currentMsg = viewModel.messages[index]
        let nextMsg = viewModel.messages[index + 1]
        return !Calendar.current.isDate(currentMsg.date, inSameDayAs: nextMsg.date)
    }
}


private struct MessageBubbleShape: Shape {
    let direction: Message.Direction
    let position: MessageClusterPosition
    let hasTail: Bool

    func path(in rect: CGRect) -> Path {
        let maxR: CGFloat = 16
        let minR: CGFloat = 4
        let tailWidth: CGFloat = 4
        let w = rect.width
        let h = rect.height

        var path = Path()

        if direction == .outgoing {
            let topL: CGFloat = maxR
            let topR: CGFloat = (position == .middle || position == .bottom) ? minR : maxR
            let botL: CGFloat = maxR
            let botR: CGFloat = (position == .top || position == .middle) ? minR : (hasTail ? tailWidth : maxR)

            path.move(to: CGPoint(x: topL, y: 0))
            path.addLine(to: CGPoint(x: w - topR, y: 0))
            path.addArc(center: CGPoint(x: w - topR, y: topR), radius: topR, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

            if hasTail {
                path.addLine(to: CGPoint(x: w, y: h - botR))
                path.addArc(center: CGPoint(x: w - botR, y: h - botR), radius: botR, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            } else {
                path.addLine(to: CGPoint(x: w, y: h - botR))
                path.addArc(center: CGPoint(x: w - botR, y: h - botR), radius: botR, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            }

            path.addLine(to: CGPoint(x: botL, y: h))
            path.addArc(center: CGPoint(x: botL, y: h - botL), radius: botL, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

            path.addLine(to: CGPoint(x: 0, y: topL))
            path.addArc(center: CGPoint(x: topL, y: topL), radius: topL, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.closeSubpath()
        } else {
            let topL: CGFloat = (position == .middle || position == .bottom) ? minR : maxR
            let topR: CGFloat = maxR
            let botL: CGFloat = (position == .top || position == .middle) ? minR : (hasTail ? tailWidth : maxR)
            let botR: CGFloat = maxR

            path.move(to: CGPoint(x: topL, y: 0))
            path.addLine(to: CGPoint(x: w - topR, y: 0))
            path.addArc(center: CGPoint(x: w - topR, y: topR), radius: topR, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

            path.addLine(to: CGPoint(x: 0, y: topL))
            path.addArc(center: CGPoint(x: topL, y: topL), radius: topL, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

            if hasTail {
                path.addLine(to: CGPoint(x: botL, y: h))
                path.addArc(center: CGPoint(x: botL, y: h - botL), radius: botL, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            } else {
                path.addLine(to: CGPoint(x: botL, y: h))
                path.addArc(center: CGPoint(x: botL, y: h - botL), radius: botL, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            }

            path.addLine(to: CGPoint(x: 0, y: topL))
            path.addArc(center: CGPoint(x: topL, y: topL), radius: topL, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.closeSubpath()
        }

        return path
    }
}


private struct MessageBubbleView: View {
    let message: Message
    let clusterPosition: MessageClusterPosition
    let isGroupChat: Bool
    let isSelected: Bool
    let reaction: String?
    let onTap: () -> Void
    let onReplyTap: (Int) -> Void
    let onImageTap: (URL) -> Void

    @Environment(\.colorScheme) var colorScheme

    private var isOutgoing: Bool {
        message.direction == .outgoing
    }

    private var hasTail: Bool {
        clusterPosition == .single || clusterPosition == .bottom
    }

    private var authorColor: Color {
        let colors: [Color] = [
            Color(red: 0.20, green: 0.55, blue: 0.90),
            Color(red: 0.18, green: 0.70, blue: 0.35),
            Color(red: 0.95, green: 0.55, blue: 0.15),
            Color(red: 0.60, green: 0.35, blue: 0.85),
            Color(red: 0.90, green: 0.25, blue: 0.50),
            Color(red: 0.05, green: 0.70, blue: 0.65),
            Color(red: 0.85, green: 0.65, blue: 0.10)
        ]
        let idx = abs(message.fromId) % colors.count
        return colors[idx]
    }

    var body: some View {
        Group {
            if let sticker = message.sticker {
                VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 2) {
                    RemoteImage(url: sticker.imageURL, placeholder: ProgressView())
                        .frame(width: 140, height: 140)
                    mediaTimePill
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    if isGroupChat && !isOutgoing && (clusterPosition == .single || clusterPosition == .top),
                       let name = message.senderName {
                        Text(name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(authorColor)
                            .padding(.horizontal, 11)
                            .padding(.top, 6)
                    }

                    if let fwd = message.forwardMessages.first {
                        forwardBanner(fwd)
                            .padding(.horizontal, 8)
                            .padding(.top, (isGroupChat && !isOutgoing) ? 2 : 6)
                    }

                    if let reply = message.replyMessage {
                        replyBanner(reply)
                            .padding(.horizontal, 8)
                            .padding(.top, (message.forwardMessages.isEmpty && isGroupChat && !isOutgoing && message.senderName != nil) ? 2 : 6)
                    }

                    if !message.attachments.isEmpty {
                        attachmentsView
                            .padding(.horizontal, 5)
                            .padding(.top, (message.replyMessage != nil || !message.forwardMessages.isEmpty || (isGroupChat && !isOutgoing && message.senderName != nil)) ? 2 : 5)
                    }

                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.system(size: 15.5))
                            .multilineTextAlignment(.leading)
                            .foregroundColor(isOutgoing ? .white : .primary)
                            .padding(.horizontal, 11)
                            .padding(.top, (message.replyMessage != nil || !message.attachments.isEmpty || !message.forwardMessages.isEmpty || (isGroupChat && !isOutgoing && message.senderName != nil)) ? 2 : 6)
                            .padding(.bottom, 1)
                    }

                    HStack(alignment: .bottom, spacing: 4) {
                        if let r = reaction {
                            Text(r)
                                .font(.system(size: 14))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(isOutgoing ? Color.white.opacity(0.2) : Color(.systemGray5)))
                                .padding(.leading, 8)
                        }

                        Spacer(minLength: 16)
                        timeStatusView
                    }
                    .padding(.bottom, 4)
                }
                .background(
                    MessageBubbleShape(direction: message.direction, position: clusterPosition, hasTail: hasTail)
                        .fill(bubbleColor)
                        .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(isOutgoing ? 0.08 : 0.05), radius: 1.5, x: 0, y: 1)
                )
                .clipShape(MessageBubbleShape(direction: message.direction, position: clusterPosition, hasTail: hasTail))
                .overlay(
                    isSelected
                        ? MessageBubbleShape(direction: message.direction, position: clusterPosition, hasTail: hasTail)
                            .stroke(Color.appAccent, lineWidth: 2)
                        : nil
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var bubbleColor: Color {
        if isOutgoing {
            return Color.appAccent
        } else {
            return colorScheme == .dark ? Color(red: 0.16, green: 0.20, blue: 0.26) : Color(.secondarySystemBackground)
        }
    }

    private func replyBanner(_ reply: MessageReply) -> some View {
        Button(action: { onReplyTap(reply.id) }) {
            HStack(spacing: 6) {
                Capsule()
                    .fill(isOutgoing ? Color.white.opacity(0.9) : Color.appAccent)
                    .frame(width: 2.5, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(reply.senderName)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(isOutgoing ? .white : .appAccent)
                    Text(reply.text.isEmpty ? "[Вложение]" : reply.text)
                        .font(.system(size: 11))
                        .foregroundColor(isOutgoing ? .white.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOutgoing ? Color.white.opacity(0.15) : Color.appAccent.opacity(0.08))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func forwardBanner(_ fwd: MessageReply) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(isOutgoing ? Color.white.opacity(0.8) : Color.appAccent.opacity(0.8))
                .frame(width: 2.5, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .font(.system(size: 9))
                    Text("Переслано от: \(fwd.senderName)")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(isOutgoing ? .white : .appAccent)

                if !fwd.text.isEmpty {
                    Text(fwd.text)
                        .font(.system(size: 11))
                        .foregroundColor(isOutgoing ? .white.opacity(0.85) : .secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isOutgoing ? Color.white.opacity(0.12) : Color.appAccent.opacity(0.06))
        )
    }

    @ViewBuilder
    private var attachmentsView: some View {
        let images = message.attachments.compactMap { att -> URL? in
            if case .remoteImage(let urlStr, _, _, _, _, _, _) = att, let u = URL(string: urlStr) {
                return u
            }
            if case .gif(_, let urlStr) = att, let u = URL(string: urlStr) {
                return u
            }
            return nil
        }

        let nonImages = message.attachments.filter { att in
            switch att {
            case .remoteImage, .gif: return false
            default: return true
            }
        }

        VStack(alignment: .leading, spacing: 4) {
            if !images.isEmpty {
                MessagePhotoGrid(images: images, onSelect: onImageTap)
            }

            ForEach(nonImages) { att in
                attachmentCard(att)
            }
        }
    }

    @ViewBuilder
    private func attachmentCard(_ att: Attachment) -> some View {
        switch att {
        case .audio(let artist, let title, let dur):
            VoiceMessageView(title: title, subtitle: artist, duration: dur, isOutgoing: isOutgoing)

        case .document(let title, let ext, let size, let url):
            DocumentMessageCard(title: title, ext: ext, size: size, url: url, isOutgoing: isOutgoing)

        case .remoteVideo(let title, let dur, let imgUrl, _, _, _, _, _, _, _, _):
            VideoMessageCard(title: title, duration: dur, imageURL: imgUrl, isOutgoing: isOutgoing)

        case .video(let title, let dur):
            VideoMessageCard(title: title, duration: dur, imageURL: "", isOutgoing: isOutgoing)

        case .note(let title, let content):
            HStack(spacing: 8) {
                Capsule()
                    .fill(isOutgoing ? Color.white.opacity(0.8) : Color.appAccent)
                    .frame(width: 2.5, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isOutgoing ? .white : .appAccent)
                    Text(content)
                        .font(.system(size: 11))
                        .foregroundColor(isOutgoing ? .white.opacity(0.85) : .secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(isOutgoing ? Color.white.opacity(0.15) : Color.appAccent.opacity(0.08)))

        default:
            EmptyView()
        }
    }

    private var timeStatusView: some View {
        HStack(spacing: 3) {
            if message.isEdited {
                Text("ред.")
                    .font(.system(size: 9.5))
                    .foregroundColor(isOutgoing ? .white.opacity(0.65) : Color(.tertiaryLabel))
            }

            if message.isImportant {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundColor(isOutgoing ? .white.opacity(0.9) : .orange)
            }

            Text(timeString(for: message.date))
                .font(.system(size: 10))
                .foregroundColor(isOutgoing ? .white.opacity(0.75) : Color(.secondaryLabel))

            if isOutgoing {
                DoubleCheckmarksView(isRead: message.isRead, size: 9, color: .white.opacity(0.9))
            }
        }
        .padding(.trailing, 8)
    }

    private var mediaTimePill: some View {
        HStack(spacing: 3) {
            Text(timeString(for: message.date))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)

            if isOutgoing {
                DoubleCheckmarksView(isRead: message.isRead, size: 8, color: .white)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.black.opacity(0.45)))
    }

    private func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}


private struct MessagePhotoGrid: View {
    let images: [URL]
    let onSelect: (URL) -> Void

    var body: some View {
        if images.count == 1, let u = images.first {
            Button(action: { onSelect(u) }) {
                RemoteImage(url: u, placeholder: ProgressView())
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, maxHeight: 240)
                    .clipped()
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        } else if images.count == 2 {
            HStack(spacing: 2) {
                ForEach(images, id: \.self) { u in
                    Button(action: { onSelect(u) }) {
                        RemoteImage(url: u, placeholder: ProgressView())
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: (UIScreen.main.bounds.width * 0.72) / 2, maxHeight: 160)
                            .clipped()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .cornerRadius(12)
        } else {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: min(images.count, 2))
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(images, id: \.self) { u in
                    Button(action: { onSelect(u) }) {
                        RemoteImage(url: u, placeholder: ProgressView())
                            .aspectRatio(contentMode: .fill)
                            .frame(minHeight: 80, maxHeight: 120)
                            .clipped()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.72)
            .cornerRadius(12)
        }
    }
}

private struct VoiceMessageView: View {
    let title: String
    let subtitle: String
    let duration: String
    let isOutgoing: Bool

    @State private var isPlaying = false

    private let waveformBars: [CGFloat] = [
        0.3, 0.5, 0.8, 1.0, 0.6, 0.4, 0.7, 0.9, 0.6, 0.4, 0.8, 1.0, 0.5, 0.7, 0.9, 0.7, 0.4, 0.6, 0.8, 0.5, 0.3
    ]

    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPlaying.toggle()
                }
                HapticManager.impact(.light)
            }) {
                Circle()
                    .fill(isOutgoing ? Color.white : Color.appAccent)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isOutgoing ? .appAccent : .white)
                            .offset(x: isPlaying ? 0 : 1)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 2) {
                    ForEach(0..<waveformBars.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(isOutgoing ? Color.white.opacity(isPlaying ? 0.95 : 0.6) : Color.appAccent.opacity(isPlaying ? 0.95 : 0.5))
                            .frame(width: 2.5, height: 18 * waveformBars[i])
                    }
                }

                HStack {
                    Text(title.isEmpty ? "Голосовое сообщение" : title)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(isOutgoing ? .white : .primary)
                        .lineLimit(1)
                    Spacer()
                    Text(duration)
                        .font(.system(size: 10.5))
                        .foregroundColor(isOutgoing ? .white.opacity(0.8) : .secondary)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isOutgoing ? Color.white.opacity(0.15) : Color(.tertiarySystemFill))
        )
        .frame(maxWidth: UIScreen.main.bounds.width * 0.70)
    }
}

private struct DocumentMessageCard: View {
    let title: String
    let ext: String
    let size: String
    let url: String
    let isOutgoing: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(isOutgoing ? Color.white.opacity(0.25) : Color.appAccent.opacity(0.18))
                .frame(width: 40, height: 40)
                .overlay(
                    VStack(spacing: 1) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 15))
                            .foregroundColor(isOutgoing ? .white : .appAccent)
                        if !ext.isEmpty {
                            Text(ext.uppercased().prefix(4))
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(isOutgoing ? .white : .appAccent)
                        }
                    }
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isOutgoing ? .white : .primary)
                    .lineLimit(1)
                Text("\(ext.uppercased()) • \(size)")
                    .font(.system(size: 11))
                    .foregroundColor(isOutgoing ? .white.opacity(0.75) : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(isOutgoing ? .white.opacity(0.85) : .appAccent)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isOutgoing ? Color.white.opacity(0.15) : Color(.tertiarySystemFill))
        )
        .frame(maxWidth: UIScreen.main.bounds.width * 0.70)
        .onTapGesture {
            if let fileUrl = URL(string: url), !url.isEmpty {
                UIApplication.shared.open(fileUrl)
            }
        }
    }
}

private struct VideoMessageCard: View {
    let title: String
    let duration: String
    let imageURL: String
    let isOutgoing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ZStack {
                if let url = URL(string: imageURL), !imageURL.isEmpty {
                    RemoteImage(url: url, placeholder: ProgressView())
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.70, maxHeight: 160)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.35))
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.70, maxHeight: 130)
                }

                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    )

                if !duration.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(duration)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.black.opacity(0.65)))
                                .padding(6)
                        }
                    }
                }
            }
            .cornerRadius(10)

            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(isOutgoing ? .white : .primary)
                    .padding(.top, 2)
                    .padding(.horizontal, 2)
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.70)
    }
}

private struct MessageDateBadge: View {
    let date: Date

    var body: some View {
        Text(dateString(for: date))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.38))
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    private func dateString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Сегодня"
        } else if calendar.isDateInYesterday(date) {
            return "Вчера"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
                formatter.dateFormat = "d MMMM"
            } else {
                formatter.dateFormat = "d MMMM yyyy"
            }
            return formatter.string(from: date).capitalized
        }
    }
}

private struct SwipeToReplyModifier: ViewModifier {
    let isIncoming: Bool
    let onReply: () -> Void

    @State private var offset: CGFloat = 0
    @State private var triggered = false

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .overlay(
                GeometryReader { _ in
                    HStack {
                        Spacer()
                        if offset < -5 {
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent)
                                    .frame(width: 30, height: 30)

                                Image(systemName: "arrowshape.turn.up.left.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(min(1.0, max(0.4, abs(offset) / 38.0)))
                            .opacity(min(1.0, abs(offset) / 25.0))
                            .offset(x: min(0, offset + 40))
                        }
                    }
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .local)
                    .onChanged { value in
                        if value.translation.width < 0 {
                            let drag = value.translation.width
                            offset = max(-55, drag * 0.6)
                            if offset < -32 && !triggered {
                                triggered = true
                                HapticManager.impact(.medium)
                            }
                        }
                    }
                    .onEnded { value in
                        if offset < -32 {
                            onReply()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                        }
                        triggered = false
                    }
            )
    }
}

private extension View {
    func swipeToReply(isIncoming: Bool, onReply: @escaping () -> Void) -> some View {
        self.modifier(SwipeToReplyModifier(isIncoming: isIncoming, onReply: onReply))
    }
}

private struct IdentifiableURL: Identifiable {
    var id: String { url.absoluteString }
    let url: URL
}

private struct FullscreenImageViewer: View {
    let url: URL
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RemoteImage(url: url, placeholder: ProgressView().tint(.white))
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { val in
                            scale = max(1.0, min(val, 4.0))
                        }
                        .onEnded { _ in
                            if scale < 1.0 {
                                withAnimation { scale = 1.0 }
                            }
                        }
                )

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(16)
                    }
                }
                Spacer()
            }
        }
    }
}

private struct PinnedMessageBar: View {
    let message: Message
    var onTap: () -> Void
    var onUnpin: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.appAccent)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Закрепленное сообщение")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.appAccent)
                    Text(message.text.isEmpty ? "[Вложение]" : message.text)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: onUnpin) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct HideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .toolbar(.hidden, for: .tabBar)
        } else {
            content
                .background(HiddenTabBarHelper())
        }
    }
}

private struct HiddenTabBarHelper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            uiViewController.hidesBottomBarWhenPushed = true
            uiViewController.tabBarController?.tabBar.isHidden = true
            uiViewController.navigationController?.tabBarController?.tabBar.isHidden = true
        }
    }
}

private func hideTabBar() {
    guard let tabBar = findTabBar() else { return }
    tabBar.isHidden = true
}

private func showTabBar() {
    guard let tabBar = findTabBar() else { return }
    tabBar.isHidden = false
}

private func findTabBar() -> UITabBar? {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = scene.windows.first else {
        return nil
    }
    return findInSubviews(window)
}

private func findInSubviews(_ view: UIView) -> UITabBar? {
    if let tabBar = view as? UITabBar { return tabBar }
    for subview in view.subviews {
        if let found = findInSubviews(subview) { return found }
    }
    return nil
}

private extension View {
    @ViewBuilder
    func isSelectingRowTap(isSelecting: Bool, action: @escaping () -> Void) -> some View {
        if isSelecting {
            self
                .contentShape(Rectangle())
                .onTapGesture(perform: action)
        } else {
            self
        }
    }
}
