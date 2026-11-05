//
//  ChatInfoViewModel.swift
//  OpenVK for iOS
//

import Foundation
import SwiftUI
import UIKit

@MainActor
final class ChatInfoViewModel: ObservableObject {
    struct MaterialState {
        var items: [ChatMaterial] = []
        var nextFrom: String?
        var isLoading = false
        var hasLoaded = false
        var error: String?
    }

    @Published private(set) var members: [ChatMember] = []
    @Published private(set) var memberCount: Int
    @Published private(set) var title: String
    @Published private(set) var photoURL: URL?
    @Published private(set) var permissions = ChatPermissionSettings()
    @Published private(set) var canEditPermissions = false
    @Published private(set) var isLoadingMembers = false
    @Published private(set) var isMuted = false
    @Published private(set) var isWorking = false
    @Published private(set) var materials: [ChatMaterialSection: MaterialState] = [:]
    @Published var selectedSection: ChatMaterialSection = .members
    @Published var errorMessage: String?
    @Published var shouldDismiss = false

    let conversation: Conversation
    private let service: ChatInfoServiceProtocol
    private var membersLoaded = false
    private var canInvite = false
    private var canPromote = false
    private var canModerate = false
    private(set) var canSeeInviteLink = false
    private(set) var canChangeInfo = false
    private var canChangePin = false
    private var canChangeInviteLink = false
    private var isOwner = false

    init(conversation: Conversation, service: ChatInfoServiceProtocol = ChatInfoService()) {
        self.conversation = conversation
        self.service = service
        memberCount = conversation.chatMemberCount ?? 0
        title = conversation.peer.displayName
        photoURL = conversation.peer.avatarURL
        selectedSection = conversation.isChat ? .members : .photos
    }

    var availableSections: [ChatMaterialSection] {
        ChatMaterialSection.allCases.filter { conversation.isChat || $0 != .members }
    }

    var canAddMembers: Bool { canInvite }
    var canEdit: Bool { canChangeInfo || canEditPermissions || canChangePin || canChangeInviteLink || canInvite || canPromote || canModerate }
    var canEditTitle: Bool { canChangeInfo }
    var canRegenerateInviteLink: Bool { canChangeInviteLink }
    var memberIDs: Set<Int> { Set(members.map(\.id)) }

    func load() {
        guard !membersLoaded else { return }
        membersLoaded = true
        if conversation.isChat {
            refreshMembers()
        } else {
            loadMaterials(selectedSection)
        }
        Task {
            if let muted = try? await service.getMuted(peerID: conversation.id) {
                isMuted = muted
            }
        }
    }

    func refreshMembers() {
        guard conversation.isChat, !isLoadingMembers else { return }
        isLoadingMembers = true
        Task {
            do {
                let page = try await service.getMembers(peerID: conversation.id)
                members = page.members.sorted { left, right in
                    if left.isOwner != right.isOwner { return left.isOwner }
                    if left.isModerator != right.isModerator { return left.isModerator }
                    return left.user.displayName.localizedCaseInsensitiveCompare(right.user.displayName) == .orderedAscending
                }
                memberCount = page.count
                if let newTitle = page.title, !newTitle.isEmpty { title = newTitle }
                if let newPhoto = page.photoURL { photoURL = newPhoto }
                canInvite = page.canInvite
                canPromote = page.canPromote
                canModerate = page.canModerate
                canSeeInviteLink = page.canSeeInviteLink
                canChangeInfo = page.canChangeInfo
                canChangePin = page.canChangePin
                canChangeInviteLink = page.canChangeInviteLink
                permissions = page.permissions
                canEditPermissions = page.canEditPermissions
                isOwner = page.isOwner
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingMembers = false
        }
    }

    func canAssign(_ member: ChatMember) -> Bool {
        canPromote && member.id > 0 && member.id != AuthService.shared.currentUser?.uid && !member.isOwner
    }

    func canExclude(_ member: ChatMember) -> Bool {
        guard canModerate, member.id != AuthService.shared.currentUser?.uid, !member.isOwner else { return false }
        return member.canKick ?? (isOwner || !member.isModerator)
    }

    func setModerator(_ member: ChatMember, enabled: Bool) {
        guard canAssign(member), !isWorking else { return }
        perform {
            try await self.service.setRole(peerID: self.conversation.id, userID: member.id, moderator: enabled)
        }
    }

    func exclude(_ member: ChatMember) {
        guard canExclude(member), !isWorking else { return }
        perform {
            try await self.service.removeUser(peerID: self.conversation.id, userID: member.id)
        }
    }

    func addUsers(_ ids: [Int], completion: @escaping (Bool) -> Void) {
        guard canInvite, !ids.isEmpty, !isWorking else { completion(false); return }
        isWorking = true
        Task {
            do {
                try await service.addUsers(peerID: conversation.id, userIDs: ids)
                isWorking = false
                refreshMembers()
                completion(true)
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
                completion(false)
            }
        }
    }

    func toggleMute() {
        guard !isWorking else { return }
        let next = !isMuted
        isWorking = true
        Task {
            do {
                try await service.setMuted(peerID: conversation.id, muted: next)
                isMuted = next
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    func updateTitle(_ newTitle: String, completion: @escaping (Bool) -> Void) {
        let value = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canChangeInfo, !value.isEmpty, !isWorking else {
            completion(false)
            return
        }
        isWorking = true
        Task {
            do {
                try await service.editTitle(peerID: conversation.id, title: value)
                title = value
                isWorking = false
                completion(true)
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
                completion(false)
            }
        }
    }

    func updatePermissions(_ updated: ChatPermissionSettings, completion: @escaping (Bool) -> Void) {
        guard canEditPermissions, !isWorking else {
            completion(false)
            return
        }
        isWorking = true
        Task {
            do {
                try await service.setPermissions(peerID: conversation.id, permissions: updated)
                permissions = updated
                isWorking = false
                refreshMembers()
                completion(true)
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
                completion(false)
            }
        }
    }

    func updateAvatar(_ data: Data) {
        guard canChangeInfo, !isWorking else { return }
        isWorking = true
        Task {
            do {
                try await service.updateChatPhoto(peerID: conversation.id, imageData: data)
                // Force a fresh member/settings response after changing the image.
                photoURL = nil
                isWorking = false
                refreshMembers()
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func removeAvatar() {
        guard canChangeInfo, !isWorking else { return }
        isWorking = true
        Task {
            do {
                try await service.deleteChatPhoto(peerID: conversation.id)
                photoURL = nil
                isWorking = false
                refreshMembers()
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func markAllAsRead() {
        MessagesService.shared.markConversationAsRead(peerID: conversation.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success: AuthService.shared.fetchCounters()
                case .failure(let error): self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func clearHistory() {
        guard !isWorking else { return }
        isWorking = true
        MessagesService.shared.deleteConversation(peerID: conversation.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success: self.shouldDismiss = true
                case .failure(let error): self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func leaveConversation() {
        guard conversation.isChat, !isWorking else { return }
        isWorking = true
        MessagesService.shared.leaveChat(peerID: conversation.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success: self.shouldDismiss = true
                case .failure(let error): self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func toggleArchive() {
        ChatArchiveStore.setArchived(
            !ChatArchiveStore.contains(conversation.id),
            peerID: conversation.id
        )
    }

    func copyInviteLink() {
        guard canSeeInviteLink else { return }
        Task {
            do {
                let link = try await service.getInviteLink(peerID: conversation.id, reset: false)
                UIPasteboard.general.url = link
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func regenerateInviteLink() {
        guard canChangeInviteLink, !isWorking else { return }
        isWorking = true
        Task {
            do {
                let link = try await service.getInviteLink(peerID: conversation.id, reset: true)
                UIPasteboard.general.url = link
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    func loadMaterials(_ section: ChatMaterialSection, more: Bool = false) {
        guard section != .members else { return }
        var state = materials[section] ?? MaterialState()
        guard !state.isLoading else { return }
        if more {
            guard let cursor = state.nextFrom, !cursor.isEmpty else { return }
        } else if state.hasLoaded {
            return
        }
        let cursor = more ? state.nextFrom : nil
        state.isLoading = true
        state.error = nil
        materials[section] = state
        Task {
            do {
                let page = try await service.getMaterials(peerID: conversation.id, section: section, startFrom: cursor)
                var updated = materials[section] ?? MaterialState()
                updated.items = more ? updated.items + page.items : page.items
                updated.nextFrom = page.nextFrom == cursor || page.items.isEmpty ? nil : page.nextFrom
                updated.hasLoaded = true
                updated.isLoading = false
                materials[section] = updated
            } catch {
                var updated = materials[section] ?? MaterialState()
                updated.isLoading = false
                updated.error = error.localizedDescription
                materials[section] = updated
            }
        }
    }

    func loadMoreIfNeeded(section: ChatMaterialSection, item: ChatMaterial) {
        guard let state = materials[section], item.id == state.items.last?.id else { return }
        loadMaterials(section, more: true)
    }

    private func perform(_ action: @escaping () async throws -> Void) {
        isWorking = true
        Task {
            do {
                try await action()
                isWorking = false
                refreshMembers()
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
