//
//  PostCard.swift
//  OpenVK for iOS
//
//  Карточка поста.
//

import SwiftUI
import AVKit
import Photos

struct PostCard: View {

    let post: Post
    var showCommentsButton: Bool = true
    var showCommentPreview: Bool = true
    var onLike: () -> Void = {}
    var onCommentTap: (Post) -> Void = { _ in }
    var onRepost: ((Int) -> Void) = { _ in }

    @State private var showGroupPlaceholderAlert = false
    @State private var selectedProfileUser: User? = nil
    @State private var selectedWallOwnerProfile: User? = nil
    @State private var selectedRepostPost: Post? = nil
    @State private var showRepostSheet = false
    @State private var isExplicitRevealed = false
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?
    
    @State private var lastComment: Comment? = nil
    @State private var isLoadingComment = false

    private var currentUID: Int {
        AuthService.shared.currentUser?.uid ?? 0
    }

    private var isOwnPost: Bool {
        post.author.uid == currentUID
    }

    private var isOnOwnWall: Bool {
        if let owner = post.ownerID {
            return owner == currentUID
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 0) {
                if !post.text.isEmpty {
                    text
                }
                if !post.attachments.isEmpty {
                    PostAttachmentsView(attachments: post.attachments) { clickedMedia in
                        if !post.isExplicit || isExplicitRevealed {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                self.selectedMedia = clickedMedia
                                self.owningPost = self.post
                            }
                        }
                    }
                }
                
                if !post.copyHistory.isEmpty {
                    ForEach(post.copyHistory) { repostedPost in
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                if !post.isExplicit || isExplicitRevealed {
                                    selectedProfileUser = repostedPost.author
                                }
                            }) {
                                repostAuthorHeaderContent(user: repostedPost.author, repostedPost: repostedPost)
                            }
                            .buttonStyle(PlainButtonStyle())

                            if !repostedPost.text.isEmpty {
                                Text(repostedPost.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .lineSpacing(3)
                                    .multilineTextAlignment(.leading)
                            }

                            if !repostedPost.attachments.isEmpty {
                                PostAttachmentsView(attachments: repostedPost.attachments) { clickedMedia in
                                    if !post.isExplicit || isExplicitRevealed {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            self.selectedMedia = clickedMedia
                                            self.owningPost = repostedPost
                                        }
                                    }
                                }
                                .padding(.horizontal, 0)
                            }
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground).opacity(0.4))
                        .cornerRadius(8)
                        .overlay(
                            HStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(width: 3)
                                Spacer()
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !post.isExplicit || isExplicitRevealed {
                                selectedRepostPost = repostedPost
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: post.isExplicit && !isExplicitRevealed ? 120 : nil)
            .overlay(
                Group {
                    if post.isExplicit && !isExplicitRevealed {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isExplicitRevealed = true
                                HapticManager.impact(.medium)
                            }
                        }) {
                            ZStack {
                                Color.black

                                VStack(alignment: .center, spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "eye.slash.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.white)
                                    }

                                    VStack(alignment: .center, spacing: 4) {
                                        Text("Содержимое поста скрыто под спойлером")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                        Text("Нажмите, чтобы просмотреть")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(24)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            )
            .clipped()
            
            actions
            
            if showCommentPreview, let lastComment = lastComment {
                HStack(alignment: .top, spacing: 8) {
                    Avatar(user: lastComment.author, size: 28)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(lastComment.author.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(lastComment.dateString)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(lastComment.text)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground).opacity(0.5))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .background(Color(.systemBackground))
        .background(navigationLinks)
        .onAppear {
            loadLastCommentIfNeeded()
        }
        .sheet(isPresented: $showRepostSheet) {
            RepostView(post: post) { repostsCount in
                if let repostsCount = repostsCount {
                    onRepost(repostsCount)
                }
                showRepostSheet = false
            }
        }
    }

    @ViewBuilder
    private var navigationLinks: some View {
        Group {
            NavigationLink(
                destination: Group {
                    if let user = selectedProfileUser {
                        ProfileView(
                            user: user,
                            selectedMedia: $selectedMedia,
                            owningPost: $owningPost
                        )
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

            NavigationLink(
                destination: Group {
                    if let user = selectedWallOwnerProfile {
                        ProfileView(
                            user: user,
                            selectedMedia: $selectedMedia,
                            owningPost: $owningPost
                        )
                    }
                },
                isActive: Binding(
                    get: { selectedWallOwnerProfile != nil },
                    set: { if !$0 { selectedWallOwnerProfile = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()

            NavigationLink(
                destination: Group {
                    if let post = selectedRepostPost {
                        if let ownerID = post.ownerID, let vkID = post.vkID {
                            PostDetailLoaderView(ownerID: ownerID, postID: vkID, selectedMedia: $selectedMedia, owningPost: $owningPost)
                        } else {
                            PostDetailView(post: post, selectedMedia: $selectedMedia, owningPost: $owningPost)
                        }
                    }
                },
                isActive: Binding(
                    get: { selectedRepostPost != nil },
                    set: { if !$0 { selectedRepostPost = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()
        }
    }

    private var canRepost: Bool {
        post.vkID != nil && (post.ownerID ?? post.author.uid) != nil
    }

    private func submitReport(reason: String) {
        let reasonText = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reasonText.isEmpty else { return }
        guard let vkID = post.vkID else { return }
        
        ReportsService.shared.addReport(ownerID: vkID, type: "post", comment: reasonText) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Post report submitted successfully!")
                case .failure(let error):
                    print("Failed to submit post report: \(error.localizedDescription)")
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Avatar(user: post.author, size: 42)
                    .contentShape(Circle())
                    .onTapGesture {
                        selectedProfileUser = post.author
                    }
                if let wallOwner = post.wallOwner {
                    Avatar(user: wallOwner, size: 17)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .contentShape(Circle())
                        .onTapGesture {
                            selectedWallOwnerProfile = wallOwner
                        }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Button(action: {
                    selectedProfileUser = post.author
                }) {
                    HStack(spacing: 4) {
                        Text(post.author.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        if post.author.isOfficial == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.appAccent)
                        }
                        SupporterBadgeView(screenName: post.author.username)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                if let wallOwner = post.wallOwner {
                    HStack(spacing: 4) {
                        Text("написал(а) на стене")
                            .font(.system(size: 12))
                            .foregroundColor(Color(.secondaryLabel))
                        Button(action: {
                            selectedWallOwnerProfile = wallOwner
                        }) {
                            HStack(spacing: 3) {
                                Text(wallOwner.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.appAccent)
                                if wallOwner.isOfficial == true {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.appAccent)
                                }
                                SupporterBadgeView(screenName: wallOwner.username, size: 10)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                HStack(spacing: 4) {
                    Text(post.timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(Color(.secondaryLabel))
                        .multilineTextAlignment(.leading)
                    if let platform = post.platform, !platform.isEmpty {
                        PlatformIconView(platform: platform, size: 10, color: Color(.tertiaryLabel))
                    }
                }
            }

            Spacer()
            
            Menu {
                if isOwnPost {
                    Button(action: {}) {
                        Label("Редактировать", systemImage: "pencil")
                    }
                    Button(action: {}) {
                        Label("Удалить", systemImage: "trash")
                    }
                    Button(action: {}) {
                        Label("Закрепить", systemImage: "pin")
                    }
                } else if isOnOwnWall {
                    Button(action: {}) {
                        Label("Удалить", systemImage: "trash")
                    }
                    Button(action: {}) {
                        Label("Закрепить", systemImage: "pin")
                    }
                    Button(action: {
                        presentTextFieldAlert(
                            title: "Пожаловаться",
                            message: "Укажите причину жалобы:",
                            placeholder: "Причина жалобы"
                        ) { reason in
                            submitReport(reason: reason)
                        }
                    }) {
                        Label("Пожаловаться", systemImage: "exclamationmark.bubble")
                    }
                } else {
                    Button(action: {}) {
                        Label("Игнорировать", systemImage: "eye.slash")
                    }
                    Button(action: {
                        presentTextFieldAlert(
                            title: "Пожаловаться",
                            message: "Укажите причину жалобы:",
                            placeholder: "Причина жалобы"
                        ) { reason in
                            submitReport(reason: reason)
                        }
                    }) {
                        Label("Пожаловаться", systemImage: "exclamationmark.bubble")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.tertiaryLabel))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func repostAuthorHeaderContent(user: User, repostedPost: Post) -> some View {
        HStack(spacing: 8) {
            Avatar(user: user, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(user.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if user.isOfficial == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.appAccent)
                    }
                    SupporterBadgeView(screenName: user.username, size: 12)
                }
                HStack(spacing: 4) {
                    Text(repostedPost.timeAgo)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    if let platform = repostedPost.platform, !platform.isEmpty {
                        PlatformIconView(platform: platform, size: 9, color: .secondary)
                    }
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var text: some View {
        Text(post.text)
            .font(.system(size: 15))
            .foregroundColor(.primary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color(.secondarySystemBackground)
            VStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.system(size: 30))
                    .foregroundColor(Color(.tertiaryLabel))
                Text("Фото")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            PostActionButton(
                icon: post.isLiked ? "heart.fill" : "heart",
                label: "\(post.likes)",
                color: post.isLiked ? .red : Color(.secondaryLabel)
            ) {
                HapticManager.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    onLike()
                }
            }
            if showCommentsButton {
                PostActionButton(icon: "bubble.left",
                                 label: "\(post.comments)",
                                 color: Color(.secondaryLabel)) {
                    onCommentTap(post)
                }
            }
            PostActionButton(icon: "arrow.2.squarepath",
                             label: "\(post.reposts)",
                             color: Color(.secondaryLabel)) {
                HapticManager.impact(.light)
                if canRepost {
                    showRepostSheet = true
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, (post.isExplicit && !isExplicitRevealed) ? 10 : 4)
        .padding(.bottom, 12)
    }

    private var mediaAttachments: [Attachment] {
        post.attachments.filter {
            switch $0 {
            case .remoteImage(_, _, _, _, _, _, _), .image(_), .remoteVideo(_, _, _, _, _, _, _, _, _, _, _), .video(_, _):
                return true
            default:
                return false
            }
        }
    }

    private func loadLastCommentIfNeeded() {
        guard showCommentPreview else { return }
        guard post.comments > 0, lastComment == nil, !isLoadingComment else { return }
        
        isLoadingComment = true
        CommentsService.shared.fetchLatestComment(ownerID: post.ownerID ?? 0, postID: post.vkID ?? 0) { result in
            DispatchQueue.main.async {
                isLoadingComment = false
                switch result {
                case .success(let comment):
                    self.lastComment = comment
                case .failure(let error):
                    print("Error loading last comment for post \(post.id): \(error)")
                }
            }
        }
    }
}

