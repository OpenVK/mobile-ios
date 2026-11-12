//
//  NewPostViewModel.swift
//  OpenVK for iOS
//

import Foundation

final class NewPostViewModel: ObservableObject {

    @Published var text: String = ""
    @Published private(set) var isSubmitting: Bool = false
    @Published var attachmentSelection = AttachmentPickerSelection() {
        didSet {
            if oldValue.pollDraft != attachmentSelection.pollDraft { savedPollAttachment = nil }
        }
    }
    private var savedPollAttachment: String?

    @Published var isExplicit: Bool = false
    @Published var fromGroup: Bool = false
    @Published var signed: Bool = false
    @Published var targetUser: User?
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false

    var canPublish: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachmentSelection.selectedPhotosData.isEmpty || !attachmentSelection.selectedAttachments.isEmpty || attachmentSelection.pollDraft != nil) && !isSubmitting
    }

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
        
        if !attachmentSelection.selectedPhotosData.isEmpty {
            service.getWallUploadServer(ownerID: ownerID) { [weak self] serverResult in
                guard let self = self else { return }
                switch serverResult {
                case .success(let uploadUrl):
                    self.uploadPhotosSequentially(
                        self.attachmentSelection.selectedPhotosData,
                        uploadURL: uploadUrl
                    ) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let attachments):
                                let joinedAttachments = (attachments + self.attachmentSelection.selectedAttachments.map(\.id)).joined(separator: ",")
                                self.createPost(attachments: joinedAttachments, onCreated: onCreated)
                            case .failure(let error):
                                self.isSubmitting = false
                                self.errorMessage = "Не удалось загрузить фотографию: \(error.localizedDescription)"
                                self.showErrorAlert = true
                            }
                        }
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
            let attachments = attachmentSelection.selectedAttachments.map(\.id).joined(separator: ",")
            createPost(attachments: attachments.isEmpty ? nil : attachments, onCreated: onCreated)
        }
    }


    private func uploadPhotosSequentially(
        _ photos: [Data],
        uploadURL: String,
        index: Int = 0,
        attachments: [String] = [],
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        guard index < photos.count else {
            completion(.success(attachments))
            return
        }

        service.uploadPhotoToServer(
            urlString: uploadURL,
            photoData: photos[index],
            ownerID: ownerID
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let attachment):
                var updatedAttachments = attachments
                updatedAttachments.append(attachment)
                self.uploadPhotosSequentially(
                    photos,
                    uploadURL: uploadURL,
                    index: index + 1,
                    attachments: updatedAttachments,
                    completion: completion
                )
            case .failure(let error):
                print("Failed to upload photo at index \(index): \(error)")
                completion(.failure(error))
            }
        }
    }

    private func createPost(attachments: String?, onCreated: @escaping (Post) -> Void) {
        if let poll = attachmentSelection.pollDraft, savedPollAttachment == nil {
            struct CreatedPoll: Decodable { let id: Int; let ownerId: Int }
            do {
                let answers = String(decoding: try JSONEncoder().encode(poll.answers), as: UTF8.self)
                APIClient.shared.call(method: "polls.create", parameters: [
                    "question": poll.question, "add_answers": answers,
                    "is_anonymous": poll.anonymous ? "1" : "0",
                    "is_multiple": poll.multiple ? "1" : "0"
                ], httpMethod: "POST", as: CreatedPoll.self) { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        switch result {
                        case .success(let response):
                            self.savedPollAttachment = "poll\(response.ownerId)_\(response.id)"
                            self.createPost(attachments: attachments, onCreated: onCreated)
                        case .failure(let error):
                            self.isSubmitting = false
                            self.errorMessage = error.localizedDescription
                            self.showErrorAlert = true
                        }
                    }
                }
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
            return
        }
        let attachmentIDs = [attachments, savedPollAttachment].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ",")
        service.createPost(
            text: text,
            ownerID: ownerID,
            attachments: attachmentIDs.isEmpty ? nil : attachmentIDs,
            explicit: isExplicit,
            fromGroup: isGroup ? fromGroup : false,
            signed: (isGroup && fromGroup) ? signed : false,
            targetUser: targetUser,
            metadata: PostPublicationMetadata(sourceURL: attachmentSelection.sourceURL, latitude: attachmentSelection.selectedPlace?.latitude, longitude: attachmentSelection.selectedPlace?.longitude, placeName: attachmentSelection.selectedPlace?.name ?? "")
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
