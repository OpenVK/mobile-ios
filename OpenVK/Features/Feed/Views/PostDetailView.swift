//
//  PostDetailView.swift
//  OpenVK for iOS
//

import SwiftUI

struct PostDetailView: View {

    @StateObject private var viewModel: CommentsViewModel
    @State private var selectedProfileUser: User?
    @State private var tappedMedia: Attachment?
    @State private var deletingComment: Comment?
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    private let post: Post
    private var currentUID: Int { AuthService.shared.currentUser?.uid ?? 0 }

    init(post: Post, selectedMedia: Binding<Attachment?> = .constant(nil), owningPost: Binding<Post?> = .constant(nil)) {
        self.post = post
        self._selectedMedia = selectedMedia
        self._owningPost = owningPost
        _viewModel = StateObject(wrappedValue: CommentsViewModel(post: post))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    PostCard(
                        post: viewModel.post,
                        showCommentsButton: false,
                        showCommentPreview: false,
                        onLike: { viewModel.togglePostLike() },
                        onCommentTap: { _ in },
                        onRepost: { repostsCount in
                            viewModel.updateRepostsCount(repostsCount)
                        },
                        selectedMedia: $tappedMedia,
                        owningPost: .constant(nil)
                    )

                    SectionSeparator()

                    HStack {
                        Text("Комментарии")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(viewModel.totalCount)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else if viewModel.comments.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.comments) { comment in
                            CommentRow(
                                comment: comment,
                                onLike: { viewModel.toggleLike(for: comment) },
                                onReply: { viewModel.setReply(to: comment) },
                                onUserTap: { id in navigateToUser(id: id, from: comment) },
                                onMediaTap: { tappedMedia = $0 },
                                onEdit: { viewModel.setEditing($0) },
                                onDelete: { deletingComment = $0 },
                                isOwnComment: comment.fromId == currentUID,
                                canDelete: comment.fromId == currentUID || viewModel.post.ownerID == currentUID
                            )
                                Divider()
                                    .padding(.leading, 70)
                            }

                            if viewModel.hasMore {
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .padding(.vertical, 20)
                                } else {
                                    Button(action: { viewModel.loadMore() }) {
                                        HStack {
                                            Spacer()
                                            Text("Загрузить ещё")
                                                .font(.system(size: 14))
                                                .foregroundColor(.appAccent)
                                            Spacer()
                                        }
                                        .padding(.vertical, 16)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if let edit = viewModel.editingComment {
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

            if let reply = viewModel.replyToComment {
                HStack {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.appAccent)
                    HStack(spacing: 4) {
                        Text("Ответ \(reply.author.displayName)")
                            .font(.system(size: 13))
                            .foregroundColor(.appAccent)
                        
                        if reply.author.isOfficial == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.appAccent)
                        }
                        SupporterBadgeView(screenName: reply.author.username, size: 12)
                    }
                    Spacer()
                    Button(action: { viewModel.cancelReply() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.appAccent.opacity(0.08))
            }

            Divider()

            CommentInputBar(
                text: $viewModel.newCommentText,
                placeholder: viewModel.replyPlaceholder,
                canSend: viewModel.canSend,
                onSend: { viewModel.sendComment() }
            )
        }
        .background(profileNavigationLink)
        .navigationBarTitle("Запись", displayMode: .inline)
        .onAppear { viewModel.load() }
        .alert("Удалить комментарий?", isPresented: .init(
            get: { deletingComment != nil },
            set: { if !$0 { deletingComment = nil } }
        )) {
            Button("Удалить", role: .destructive) {
                if let comment = deletingComment {
                    viewModel.deleteComment(comment)
                }
                deletingComment = nil
            }
            Button("Отмена", role: .cancel) {
                deletingComment = nil
            }
        } message: {
            Text("Это действие нельзя отменить.")
        }
        .fullScreenCover(item: $tappedMedia) { media in
            if let comment = viewModel.comments.first(where: { c in
                c.attachments.contains(where: { $0.id == media.id })
            }) {
                let commentMedia = comment.attachments.filter {
                    switch $0 {
                    case .remoteImage, .image, .remoteVideo, .video, .gif: return true
                    default: return false
                    }
                }
                let index = commentMedia.firstIndex(where: { $0.id == media.id }) ?? 0
                MediaFullScreenViewer(
                    post: Post(
                        author: comment.author,
                        timeAgo: comment.dateString,
                        text: "",
                        attachments: comment.attachments
                    ),
                    attachments: commentMedia,
                    initialSelectedIndex: index,
                    onLikeToggle: {},
                    onCommentTap: {},
                    onDismiss: { tappedMedia = nil }
                )
            } else {
                let (displayPost, displayAttachments) = resolvePostAndAttachments(for: media, in: post)
                let index = displayAttachments.firstIndex(where: { $0.id == media.id }) ?? 0
                MediaFullScreenViewer(
                    post: displayPost,
                    attachments: displayAttachments,
                    initialSelectedIndex: index,
                    onLikeToggle: { viewModel.togglePostLike() },
                    onCommentTap: {},
                    onDismiss: { tappedMedia = nil }
                )
            }
        }
    }

    @ViewBuilder
    private var profileNavigationLink: some View {
        NavigationLink(
            destination: Group {
                if let user = selectedProfileUser {
                    ProfileView(user: user, selectedMedia: $selectedMedia, owningPost: $owningPost)
                }
            },
            isActive: Binding(
                get: { selectedProfileUser != nil },
                set: { if !$0 { selectedProfileUser = nil } }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    private func navigateToUser(id: Int, from comment: Comment) {
        if id == comment.fromId {
            selectedProfileUser = comment.author
        } else {
            let name = comment.text.mentionName(for: id) ?? "id\(abs(id))"
            selectedProfileUser = User(
                uid: id,
                username: id > 0 ? "id\(id)" : "club\(abs(id))",
                displayName: name,
                isGroup: id < 0
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.system(size: 40))
                .foregroundColor(Color(.tertiaryLabel))
            Text("Комментариев пока нет")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            Text("Станьте первым!")
                .font(.system(size: 13))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 60)
    }
}

private struct CommentInputBar: View {

    @Binding var text: String
    @State private var textHeight: CGFloat = 36
    let placeholder: String
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(spacing: 4) {
                CommentTextView(text: $text, placeholder: placeholder, height: $textHeight)
                    .frame(height: min(textHeight, 120))

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
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
        .padding(.vertical, 8)
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

extension String {
    func mentionName(for id: Int) -> String? {
        let pattern = try! NSRegularExpression(pattern: "\\[(id|club)(\\d+)\\|([^\\]]+)\\]")
        let matches = pattern.matches(in: self, range: NSRange(startIndex..., in: self))
        for match in matches {
            let typeRange = Range(match.range(at: 1), in: self)!
            let idRange = Range(match.range(at: 2), in: self)!
            let nameRange = Range(match.range(at: 3), in: self)!
            let type = self[typeRange]
            let mid = Int(self[idRange]) ?? 0
            let resolvedId = type == "club" ? -mid : mid
            if resolvedId == id {
                return String(self[nameRange])
            }
        }
        return nil
    }
}
