//
//  CommentsViewModel.swift
//  OpenVK for iOS
//

import Foundation
import Combine

final class CommentsViewModel: ObservableObject {

    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var newCommentText = ""
    @Published var totalCount = 0
    @Published var error: String?
    @Published var replyToComment: Comment?
    @Published var editingComment: Comment?

    @Published var post: Post
    private let service: CommentsServiceProtocol
    private let pageSize = 20
    private var currentOffset = 0
    private(set) var hasMore = true

    var canSend: Bool {
        !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var replyPlaceholder: String {
        if editingComment != nil {
            return "Редактировать комментарий"
        }
        if let reply = replyToComment {
            return "Ответить \(reply.author.displayName)"
        }
        return "Написать комментарий"
    }

    init(post: Post, service: CommentsServiceProtocol = CommentsService.shared) {
        self.post = post
        self.service = service
    }

    func load() {
        guard let ownerID = post.ownerID, let postID = post.vkID else { return }
        isLoading = true
        error = nil
        currentOffset = 0

        service.fetchComments(ownerID: ownerID, postID: postID, offset: 0, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    self?.comments = response.comments
                    self?.totalCount = response.count
                    self?.currentOffset = response.comments.count
                    self?.hasMore = response.comments.count < response.count
                case .failure(let error):
                    self?.error = error.localizedDescription
                }
            }
        }
    }

    func loadMore() {
        guard !isLoadingMore, hasMore else { return }
        guard let ownerID = post.ownerID, let postID = post.vkID else { return }

        isLoadingMore = true
        service.fetchComments(ownerID: ownerID, postID: postID, offset: currentOffset, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMore = false
                switch result {
                case .success(let response):
                    self?.comments.append(contentsOf: response.comments)
                    self?.currentOffset += response.comments.count
                    self?.hasMore = (self?.currentOffset ?? 0) < response.count
                case .failure:
                    break
                }
            }
        }
    }

    func sendComment() {
        var text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let ownerID = post.ownerID, let postID = post.vkID else { return }

        if let edit = editingComment {
            newCommentText = ""
            editingComment = nil
            editComment(edit, newText: text)
            return
        }

        if let reply = replyToComment {
            text = "[id\(reply.fromId)|\(reply.author.displayName)], \(text)"
        }

        newCommentText = ""
        replyToComment = nil
        service.createComment(ownerID: ownerID, postID: postID, text: text) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let comment) = result {
                    self?.comments.append(comment)
                    self?.totalCount += 1
                }
            }
        }
    }

    func editComment(_ comment: Comment, newText: String) {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        guard let ownerID = post.ownerID else { return }

        let updated = Comment(
            id: comment.id,
            postId: comment.postId,
            fromId: comment.fromId,
            ownerId: comment.ownerId,
            author: comment.author,
            text: newText,
            date: comment.date,
            likesCount: comment.likesCount,
            isLiked: comment.isLiked,
            attachments: comment.attachments
        )
        comments[index] = updated

        service.editComment(commentID: comment.id, ownerID: ownerID, text: newText) { result in
            DispatchQueue.main.async {
                if case .failure = result {
                    self.comments[index] = comment
                }
            }
        }
    }

    func deleteComment(_ comment: Comment) {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        guard let ownerID = post.ownerID else { return }

        comments.remove(at: index)
        totalCount -= 1
        service.deleteComment(commentID: comment.id, ownerID: ownerID) { result in
            DispatchQueue.main.async {
                if case .failure = result {
                    self.comments.insert(comment, at: index)
                    self.totalCount += 1
                }
            }
        }
    }

    func setReply(to comment: Comment) {
        editingComment = nil
        replyToComment = comment
    }

    func cancelReply() {
        replyToComment = nil
    }

    func setEditing(_ comment: Comment) {
        replyToComment = nil
        editingComment = comment
        newCommentText = comment.text
    }

    func cancelEditing() {
        editingComment = nil
        newCommentText = ""
    }

    func togglePostLike() {
        guard let ownerID = post.ownerID, let postID = post.vkID else { return }

        let wasLiked = post.isLiked
        post.isLiked.toggle()
        post.likes += wasLiked ? -1 : 1

        service.togglePostLike(ownerID: ownerID, postID: postID, isLiked: wasLiked) { [weak self] result in
            DispatchQueue.main.async {
                if case .failure = result {
                    self?.post.isLiked = wasLiked
                    self?.post.likes += wasLiked ? 1 : -1
                }
            }
        }
    }

    func updateRepostsCount(_ count: Int) {
        post.reposts = count
    }

    func toggleLike(for comment: Comment) {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }

        let optimistic = optimisticComment(comment, isLiked: !comment.isLiked)
        comments[index] = optimistic

        service.toggleLike(commentID: comment.id, ownerID: comment.ownerId, isLiked: comment.isLiked) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self,
                      let idx = self.comments.firstIndex(where: { $0.id == comment.id }) else { return }
                switch result {
                case .success(let response):
                    self.comments[idx] = self.optimisticComment(comment, isLiked: response.isLiked, likesCount: response.likesCount)
                case .failure:
                    self.comments[idx] = comment
                }
            }
        }
    }

    private func optimisticComment(_ comment: Comment, isLiked: Bool, likesCount: Int? = nil) -> Comment {
        let count = likesCount ?? (isLiked ? comment.likesCount + 1 : max(0, comment.likesCount - 1))
        return Comment(
            id: comment.id,
            postId: comment.postId,
            fromId: comment.fromId,
            ownerId: comment.ownerId,
            author: comment.author,
            text: comment.text,
            date: comment.date,
            likesCount: count,
            isLiked: isLiked,
            attachments: comment.attachments
        )
    }
}
