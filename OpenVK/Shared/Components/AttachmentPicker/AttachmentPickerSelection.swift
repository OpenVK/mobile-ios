//
//  AttachmentPickerSelection.swift
//  OpenVK for iOS
//
//


import Foundation

struct PickerAttachment: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
}

struct AttachmentPollDraft: Equatable {
    let question: String
    let answers: [String]
    let anonymous: Bool
    let multiple: Bool
}

struct AttachmentPlace: Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
}

struct AttachmentPickerSelection {
    var selectedPhotosData: [Data] = []
    var selectedAttachments: [PickerAttachment] = []
    var pollDraft: AttachmentPollDraft?
    var selectedPlace: AttachmentPlace?
    var sourceURL = ""
    var maximumAttachments = 10

    var attachmentCount: Int {
        selectedPhotosData.count + selectedAttachments.count + (pollDraft == nil ? 0 : 1)
    }

    var remainingAttachmentSlots: Int { max(0, maximumAttachments - attachmentCount) }

    var hasAttachments: Bool {
        attachmentCount > 0 || selectedPlace != nil || !sourceURL.isEmpty
    }
}
