//
//  ChatView.swift
//  OpenVK for iOS
//

import SwiftUI
import UIKit

struct ChatView: View {

    let conversation: Conversation

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
                        viewModel.scrollToMessageId = pinned.id
                    }
                } onUnpin: {
                    viewModel.unpinCurrentMessage()
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding(.vertical, 30)
                                .rotationEffect(.degrees(180))
                        }

                        ForEach(viewModel.messages) { msg in
                            messageRow(msg)
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
                    .padding(.vertical, 8)
                }
                .rotationEffect(.degrees(180))
                .onChange(of: viewModel.scrollToMessageId) { targetId in
                    if let targetId = targetId {
                        withAnimation {
                            proxy.scrollTo(targetId, anchor: .center)
                        }
                        viewModel.scrollToMessageId = nil
                    }
                }
            }

            if viewModel.isPeerTyping, let typingText = viewModel.peerTypingText {
                HStack(spacing: 6) {
                    TypingIndicatorDots()
                    Text(typingText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemBackground))
            }

            bottomBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                principalToolbarContent
            }
        }
        .chatToolbar(
            isSelecting: viewModel.isSelecting,
            deleteAction: { showBatchDeleteConfirmation = true },
            cancelAction: { viewModel.clearSelection() }
        )
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
    }

    @ViewBuilder
    private func messageRow(_ msg: Message) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 6) {
                if msg.direction == .incoming {
                    Spacer()
                }

                if viewModel.isSelecting {
                    MessageBubble(
                        message: msg,
                        isGroupChat: conversation.peer.type == .chat,
                        isSelected: viewModel.selectedMessageIds.contains(msg.id),
                        onTap: { viewModel.toggleSelection(msg.id) },
                        onReplyTap: { replyId in
                            viewModel.scrollToMessageId = replyId
                        }
                    )
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.76, alignment: msg.direction == .outgoing ? .leading : .trailing)
                } else {
                    Menu {
                        Button(action: { viewModel.startReply(to: msg) }) {
                            Label("Ответить", systemImage: "arrowshape.turn.up.left")
                        }

                        if !msg.text.isEmpty {
                            Button(action: { UIPasteboard.general.string = msg.text }) {
                                Label("Скопировать", systemImage: "doc.on.doc")
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

                        Button(role: .destructive, action: {
                            deleteMessageId = msg.id
                            deleteForAll = true
                            showDeleteAlert = true
                        }) {
                            Label("Удалить", systemImage: "trash")
                        }

                        Button(action: { viewModel.toggleSelection(msg.id) }) {
                            Label("Выбрать", systemImage: "checklist")
                        }
                    } label: {
                        MessageBubble(
                            message: msg,
                            isGroupChat: conversation.peer.type == .chat,
                            isSelected: false,
                            onTap: {},
                            onReplyTap: { replyId in
                                viewModel.scrollToMessageId = replyId
                            }
                        )
                    } primaryAction: {
                    }
                    .buttonStyle(PlainButtonStyle())
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.76, alignment: msg.direction == .outgoing ? .leading : .trailing)
                }

                if msg.direction == .incoming {
                    if conversation.peer.type == .chat {
                        Avatar(url: msg.senderAvatarURL, placeholderSystemName: "person.fill", size: 28)
                            .rotationEffect(.degrees(180))
                    }
                } else {
                    Spacer()
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
            .padding(.vertical, 2)
            .padding(.horizontal, 12)
            .isSelectingRowTap(isSelecting: viewModel.isSelecting) {
                viewModel.toggleSelection(msg.id)
            }

            if let index = viewModel.messages.firstIndex(where: { $0.id == msg.id }),
               isLastMessageOfDay(at: index) {
                DateSeparator(date: msg.date)
                    .rotationEffect(.degrees(180))
            }
        }
    }

    private var principalToolbarContent: some View {
        if viewModel.isSelecting {
            return AnyView(
                Text("Выбрано: \(viewModel.selectedMessageIds.count)")
                    .font(.system(size: 16, weight: .semibold))
            )
        }

        return AnyView(
            Button(action: {
                if conversation.peer.type == .chat {
                    showChatDetails = true
                } else {
                    showProfile = true
                }
            }) {
                HStack(spacing: 8) {
                    Avatar(peer: conversation.peer, size: 30)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(conversation.peer.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            if conversation.peer.isOfficial == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.appAccent)
                            }
                        }

                        if conversation.peer.type == .chat {
                            Text("\(conversation.peer.membersCount ?? 1) участников")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else if conversation.peer.isOnline == true {
                            Text("в сети")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        } else {
                            Text("OpenVK")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            if let reply = viewModel.replyingToMessage {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(reply.senderName ?? "Ответ")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appAccent)
                        Text(reply.text.isEmpty ? "[Вложение]" : reply.text)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: { viewModel.cancelReply() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
            }

            if viewModel.editingMessageId != nil {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.appAccent)
                    Text("Редактирование")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appAccent)
                    Spacer()
                    Button(action: { viewModel.cancelEditing() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.appAccent.opacity(0.08))
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: { showStickerPicker = true }) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 6)

                HStack(alignment: .bottom, spacing: 4) {
                    TextField(
                        viewModel.editingMessageId != nil ? "Изменить сообщение..." : "Сообщение...",
                        text: $viewModel.draft
                    )
                    .font(.system(size: 16))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(18)

                Button(action: {
                    if viewModel.editingMessageId != nil {
                        viewModel.saveEdit()
                    } else {
                        viewModel.send()
                    }
                }) {
                    Image(systemName: viewModel.editingMessageId != nil ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(
                            !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? .appAccent
                                : Color(.systemGray4)
                        )
                }
                .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
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

// MARK: - Message Bubble Component

private struct MessageBubble: View {
    let message: Message
    let isGroupChat: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onReplyTap: (Int) -> Void

    var body: some View {
        Group {
            if let sticker = message.sticker {
                VStack(alignment: message.direction == .outgoing ? .trailing : .leading, spacing: 2) {
                    RemoteImage(url: sticker.imageURL, placeholder: ProgressView())
                        .frame(width: 140, height: 140)
                    timeStatusView
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if isGroupChat && message.direction == .incoming, let name = message.senderName {
                        Text(name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appAccent)
                            .padding(.horizontal, 12)
                            .padding(.top, 6)
                    }

                    if let reply = message.replyMessage {
                        Button(action: { onReplyTap(reply.id) }) {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(message.direction == .outgoing ? Color.white.opacity(0.8) : Color.appAccent)
                                    .frame(width: 2.5)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(reply.senderName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(message.direction == .outgoing ? .white : .appAccent)
                                    Text(reply.text.isEmpty ? "[Вложение]" : reply.text)
                                        .font(.system(size: 11))
                                        .foregroundColor(message.direction == .outgoing ? .white.opacity(0.8) : .secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(message.direction == .outgoing ? Color.white.opacity(0.15) : Color.appAccent.opacity(0.08))
                            )
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                    }

                    if !message.attachments.isEmpty {
                        attachmentsView
                    }

                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.system(size: 15))
                            .multilineTextAlignment(.leading)
                            .foregroundColor(message.direction == .outgoing ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.top, (isGroupChat && message.direction == .incoming) || message.replyMessage != nil ? 0 : 6)
                            .padding(.bottom, 2)
                    }

                    timeStatusView
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(message.direction == .outgoing
                            ? Color.appAccent
                            : Color(.secondarySystemBackground))
                )
                .cornerRadius(16)
                .overlay(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.appAccent, lineWidth: 2.5)
                            .colorMultiply(Color(white: 0.75))
                        : nil
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var attachmentsView: some View {
        VStack(spacing: 4) {
            ForEach(message.attachments) { att in
                switch att {
                case .remoteImage(let url, _, _, _, _, _, _):
                    if let imgUrl = URL(string: url) {
                        RemoteImage(url: imgUrl, placeholder: ProgressView())
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(10)
                            .padding(.horizontal, 6)
                    }
                case .remoteVideo(let title, let dur, let img, _, _, _, _, _, _, _, _):
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.appAccent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Text(dur)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(8)
                case .audio(let artist, let title, let dur):
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundColor(.appAccent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Text("\(artist) • \(dur)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(8)
                case .document(let title, let ext, let size, _):
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.appAccent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Text("\(ext.uppercased()) • \(size)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(8)
                default:
                    EmptyView()
                }
            }
        }
        .padding(.top, 4)
    }

    private var timeStatusView: some View {
        HStack(spacing: 3) {
            Spacer()

            if message.isEdited {
                Text("ред.")
                    .font(.system(size: 9))
                    .foregroundColor(message.direction == .outgoing ? .white.opacity(0.6) : Color(.tertiaryLabel))
            }

            if message.isImportant {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundColor(message.direction == .outgoing ? .white.opacity(0.9) : .orange)
            }

            Text(timeString(for: message.date))
                .font(.system(size: 10))
                .foregroundColor(message.direction == .outgoing ? .white.opacity(0.7) : Color(.secondaryLabel))

            if message.direction == .outgoing {
                Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 5)
    }

    private func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct DateSeparator: View {
    let date: Date

    var body: some View {
        Text(dateString(for: date))
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(.systemGray6)))
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
    func chatToolbar(
        isSelecting: Bool,
        deleteAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) -> some View {
        if isSelecting {
            self.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: deleteAction) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена", action: cancelAction)
                }
            }
        } else {
            self
        }
    }

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
