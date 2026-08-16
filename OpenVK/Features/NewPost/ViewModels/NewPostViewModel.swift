//
//  NewPostViewModel.swift
//  OpenVK for iOS
//

import Foundation

final class NewPostViewModel: ObservableObject {

    @Published var text: String = ""
    @Published private(set) var isSubmitting: Bool = false
    @Published var selectedPhotosData: [Data] = []
    @Published var isExplicit: Bool = false
    @Published var fromGroup: Bool = false
    @Published var signed: Bool = false
    @Published var targetUser: User?
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false

    var canPublish: Bool { (!text.isEmpty || !selectedPhotosData.isEmpty) && !isSubmitting }

    var isGroup: Bool {
        (ownerID ?? 0) < 0 || targetUser?.isGroup == true
    }

    var canPostAsGroup: Bool {
        targetUser?.isAdmin == true
    }

    var hasActiveOptions: Bool {
        if isGroup {
            return isExplicit || fromGroup || signed
        } else {
            return isExplicit
        }
    }

    let ownerID: Int?
    private let service: FeedServiceProtocol

    init(ownerID: Int? = nil, targetUser: User? = nil, service: FeedServiceProtocol = FeedService.shared) {
        let resolvedOwnerID = ownerID ?? targetUser?.uid
        self.ownerID = resolvedOwnerID
        self.targetUser = targetUser
        self.service = service

        let isGrp = (resolvedOwnerID ?? 0) < 0 || targetUser?.isGroup == true
        if isGrp {
            if targetUser?.isAdmin == true {
                self.fromGroup = true
            }
            if targetUser == nil, let oid = resolvedOwnerID, oid < 0 {
                loadTargetGroup(id: abs(oid))
            }
        }
    }

    private func loadTargetGroup(id: Int) {
        ProfileService.shared.fetchProfile(username: "club\(id)") { [weak self] result in
            if case .success(let loaded) = result {
                DispatchQueue.main.async {
                    self?.targetUser = loaded
                    if loaded.isAdmin == true {
                        self?.fromGroup = true
                    }
                }
            }
        }
    }

    func publish(onCreated: @escaping (Post) -> Void) {
        guard canPublish else { return }
        isSubmitting = true
        
        if !selectedPhotosData.isEmpty {
            service.getWallUploadServer(ownerID: ownerID) { [weak self] serverResult in
                guard let self = self else { return }
                switch serverResult {
                case .success(let uploadUrl):
                    let group = DispatchGroup()
                    var attachments: [String] = Array(repeating: "", count: self.selectedPhotosData.count)
                    var uploadError: Error? = nil
                    
                    for (index, photoData) in self.selectedPhotosData.enumerated() {
                        group.enter()
                        self.service.uploadPhotoToServer(urlString: uploadUrl, photoData: photoData, ownerID: self.ownerID) { result in
                            switch result {
                            case .success(let attachment):
                                attachments[index] = attachment
                            case .failure(let error):
                                print("Failed to upload photo at index \(index): \(error)")
                                uploadError = error
                            }
                            group.leave()
                        }
                    }
                    
                    group.notify(queue: .main) {
                        if let error = uploadError {
                            self.isSubmitting = false
                            self.errorMessage = "Не удалось загрузить фотографию: \(error.localizedDescription)"
                            self.showErrorAlert = true
                            return
                        }
                        
                        let joinedAttachments = attachments.filter { !$0.isEmpty }.joined(separator: ",")
                        self.createPost(attachments: joinedAttachments, onCreated: onCreated)
                    }
                case .failure(let error):
                    print("Failed to get upload server: \(error)")
                    DispatchQueue.main.async {
                        self.isSubmitting = false
                        self.errorMessage = "Не удалось получить сервер загрузки: \(error.localizedDescription)"
                        self.showErrorAlert = true
                    }
                }
            }
        } else {
            createPost(attachments: nil, onCreated: onCreated)
        }
    }

    private func createPost(attachments: String?, onCreated: @escaping (Post) -> Void) {
        service.createPost(
            text: text,
            ownerID: ownerID,
            attachments: attachments,
            explicit: isExplicit,
            fromGroup: isGroup ? fromGroup : false,
            signed: (isGroup && fromGroup) ? signed : false,
            targetUser: targetUser
        ) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isSubmitting = false
                switch result {
                case .success(let post):
                    onCreated(post)
                case .failure(let error):
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .vk(let code, let message):
                            if code == 15 || message.localizedCaseInsensitiveContains("access denied") {
                                self.errorMessage = "Публикация на стене этого пользователя или сообщества запрещена настройками приватности."
                            } else {
                                self.errorMessage = apiError.localizedDescription
                            }
                        default:
                            self.errorMessage = apiError.localizedDescription
                        }
                    } else {
                        let desc = error.localizedDescription
                        if desc.localizedCaseInsensitiveContains("access denied") || desc.contains("15") {
                            self.errorMessage = "Публикация на стене этого пользователя или сообщества запрещена настройками приватности."
                        } else {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                    self.showErrorAlert = true
                }
            }
        }
    }
}
