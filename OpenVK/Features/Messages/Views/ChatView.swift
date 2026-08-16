//
//  ChatView.swift
//  OpenVK for iOS
//

import SwiftUI
import UIKit

private struct CommentInputBar: View {

    @Binding var text: String
    @State private var textHeight: CGFloat = 36
    let placeholder: String
    let canSend: Bool
    let isEditing: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(spacing: 4) {
                CommentTextView(text: $text, placeholder: placeholder, height: $textHeight)
                    .frame(height: min(textHeight, 120))

                Button(action: onSend) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(canSend ? .appAccent : Color(.systemGray4))
                }
                .disabled(!canSend)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(18)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }
}

private class BoundedTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width = UIView.noIntrinsicMetric
        return size
    }
}

private struct CommentTextView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let tv = BoundedTextView()
        tv.backgroundColor = .clear
        tv.font = .systemFont(ofSize: 16)
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 4)
        tv.delegate = context.coordinator
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.isScrollEnabled = false

        let label = UILabel()
        label.text = placeholder
        label.font = tv.font
        label.textColor = .placeholderText
        label.translatesAutoresizingMaskIntoConstraints = false
        tv.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: tv.textContainerInset.left + tv.textContainer.lineFragmentPadding),
            label.trailingAnchor.constraint(equalTo: tv.trailingAnchor, constant: -tv.textContainerInset.right - tv.textContainer.lineFragmentPadding),
            label.topAnchor.constraint(equalTo: tv.topAnchor, constant: tv.textContainerInset.top),
            label.bottomAnchor.constraint(lessThanOrEqualTo: tv.bottomAnchor, constant: -tv.textContainerInset.bottom)
        ])
        context.coordinator.placeholderLabel = label

        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty
        updateHeight(uiView)
    }

    private func updateHeight(_ tv: UITextView) {
        let maxHeight: CGFloat = 120
        guard tv.bounds.width > 50 else { return }
        let fittingSize = tv.sizeThatFits(CGSize(width: tv.bounds.width, height: .greatestFiniteMagnitude))
        let newHeight = max(fittingSize.height, 36)
        if abs(newHeight - height) > 0.5 {
            height = min(newHeight, maxHeight)
        }
        tv.isScrollEnabled = newHeight > maxHeight
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, height: $height)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var height: CGFloat
        var placeholderLabel: UILabel?

        init(text: Binding<String>, height: Binding<CGFloat>) {
            self._text = text
            self._height = height
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            placeholderLabel?.isHidden = !text.isEmpty
            let maxHeight: CGFloat = 120
            guard textView.bounds.width > 50 else { return }
            let fittingSize = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude))
            let newHeight = max(fittingSize.height, 36)
            if abs(newHeight - height) > 0.5 {
                height = min(newHeight, maxHeight)
            }
            textView.isScrollEnabled = newHeight > maxHeight
        }
    }
}

struct ChatView: View {

    let conversation: Conversation

    @StateObject private var viewModel: ChatViewModel
    @State private var didScrollToBottom = false
    @State private var showProfile = false
    @State private var deleteMessageId: Int?
    @State private var showDeleteAlert = false
    @State private var showBatchDeleteConfirmation = false
    @State private var selectedMedia: Attachment? = nil
    @State private var owningPost: Post? = nil

    init(conversation: Conversation) {
        self.conversation = conversation
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            peerID: conversation.peer.uid ?? 0,
            peerName: conversation.peer.displayName
        ))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.vertical, 40)
                        .rotationEffect(.degrees(180))
                }

                ForEach(viewModel.messages) { msg in
                    HStack(spacing: 6) {
                        if msg.direction == .incoming { Spacer() }

                        if viewModel.isSelecting {
                            MessageBubble(
                                message: msg,
                                isSelected: viewModel.selectedMessageIds.contains(msg.id),
                                onTap: {
                                    viewModel.toggleSelection(msg.id)
                                }
                            )
                            .id(msg.id)
                            .rotationEffect(.degrees(180))
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: msg.direction == .outgoing ? .leading : .trailing)
                        } else {
                            Menu {
                                if msg.direction == .outgoing {
                                    Button(action: { viewModel.startEditing(msg) }) {
                                        Label("Изменить", systemImage: "pencil")
                                    }
                                }
                                Button(action: {
                                    deleteMessageId = msg.id
                                    showDeleteAlert = true
                                }) {
                                    Label("Удалить", systemImage: "trash")
                                }
                                Button(action: { viewModel.toggleSelection(msg.id) }) {
                                    Label(viewModel.selectedMessageIds.contains(msg.id) ? "Отменить выбор" : "Выбрать", systemImage: "checklist")
                                }
                            } label: {
                                MessageBubble(
                                    message: msg,
                                    isSelected: false,
                                    onTap: {}
                                )
                            } primaryAction: {
                            }
                            .buttonStyle(PlainButtonStyle())
                            .id(msg.id)
                            .rotationEffect(.degrees(180))
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: msg.direction == .outgoing ? .leading : .trailing)
                        }

                        if msg.direction == .outgoing { Spacer() }

                        if viewModel.isSelecting {
                            Image(systemName: viewModel.selectedMessageIds.contains(msg.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(viewModel.selectedMessageIds.contains(msg.id) ? .appAccent : Color(.systemGray4))
                                .rotationEffect(.degrees(180))
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                                .onTapGesture {
                                    viewModel.toggleSelection(msg.id)
                                }
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal)
                    .isSelectingRowTap(isSelecting: viewModel.isSelecting) {
                        viewModel.toggleSelection(msg.id)
                    }

                    if let index = viewModel.messages.firstIndex(where: { $0.id == msg.id }),
                       isLastMessageOfDay(at: index) {
                        DateSeparator(date: msg.date)
                            .rotationEffect(.degrees(180))
                    }
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
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()

                if viewModel.editingMessageId != nil {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundColor(.appAccent)
                        Text("Редактирование")
                            .font(.system(size: 13))
                            .foregroundColor(.appAccent)
                        Spacer()
                        Button(action: { viewModel.cancelEditing() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.appAccent.opacity(0.08))
                }

                CommentInputBar(
                    text: $viewModel.draft,
                    placeholder: viewModel.editingMessageId != nil ? "Изменить сообщение" : "Сообщение",
                    canSend: !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    isEditing: viewModel.editingMessageId != nil,
                    onSend: {
                        if viewModel.editingMessageId != nil {
                            viewModel.saveEdit()
                        } else {
                            viewModel.send()
                        }
                    }
                )
            }
            .background(Color(.systemBackground))
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
            NavigationLink(
                destination: ProfileView(user: conversation.peer, selectedMedia: $selectedMedia, owningPost: $owningPost),
                isActive: $showProfile
            ) {
                EmptyView()
            }
            .hidden()
        )
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Удалить сообщение?"),
                primaryButton: .destructive(Text("Удалить")) {
                    if let id = deleteMessageId {
                        viewModel.deleteMessage(id)
                    }
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
        .alert(isPresented: $showBatchDeleteConfirmation) {
            Alert(
                title: Text("Удалить выбранные сообщения?"),
                primaryButton: .destructive(Text("Удалить")) { viewModel.deleteSelected() },
                secondaryButton: .cancel(Text("Отмена"))
            )
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
            Button(action: { showProfile = true }) {
                HStack(spacing: 8) {
                    Avatar(user: conversation.peer, size: 28)
                    HStack(spacing: 4) {
                        Text(conversation.peer.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if conversation.peer.isOfficial == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.appAccent)
                        }
                        SupporterBadgeView(screenName: conversation.peer.username)
                    }
                }
            }
        )
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

private struct MessageBubble: View {
    let message: Message
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(message.text)
                .font(.system(size: 16))
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)
                .foregroundColor(message.direction == .outgoing ? .white : .primary)

            Text(timeString(for: message.date))
                .font(.system(size: 10))
                .foregroundColor(message.direction == .outgoing ? .white.opacity(0.7) : Color(.secondaryLabel))
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
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
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
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
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
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
