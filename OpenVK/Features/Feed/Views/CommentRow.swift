//
//  CommentRow.swift
//  OpenVK for iOS
//

import SwiftUI

struct CommentRow: View {

    let comment: Comment
    let onLike: () -> Void
    let onReply: () -> Void
    let onUserTap: (Int) -> Void
    var onMediaTap: ((Attachment) -> Void)? = nil
    var onEdit: ((Comment) -> Void)? = nil
    var onDelete: ((Comment) -> Void)? = nil
    var isOwnComment = false
    var canDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { onUserTap(comment.fromId) }) {
                Avatar(user: comment.author, size: 36)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Button(action: { onUserTap(comment.fromId) }) {
                        HStack(spacing: 4) {
                            Text(comment.author.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if comment.author.isOfficial == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.appAccent)
                            }
                            SupporterBadgeView(screenName: comment.author.username)
                        }
                    }

                    Text(comment.dateString)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()
                }

                MentionText(text: comment.text, onUserTap: onUserTap)

                if !comment.attachments.isEmpty {
                    CommentAttachmentsView(attachments: comment.attachments, onMediaTap: onMediaTap)
                        .padding(.top, 4)
                }

                HStack(spacing: 16) {
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 13))
                            if comment.likesCount > 0 {
                                Text("\(comment.likesCount)")
                                    .font(.system(size: 12))
                            }
                        }
                        .foregroundColor(comment.isLiked ? .red : Color(.secondaryLabel))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: onReply) {
                        Text("Ответить")
                            .font(.system(size: 12))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                    .buttonStyle(PlainButtonStyle())

                    if isOwnComment {
                        Button(action: { onEdit?(comment) }) {
                            Text("Изменить")
                                .font(.system(size: 12))
                                .foregroundColor(Color(.secondaryLabel))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    if canDelete {
                        Button(action: { onDelete?(comment) }) {
                            Text("Удалить")
                                .font(.system(size: 12))
                                .foregroundColor(Color(.secondaryLabel))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    if !isOwnComment {
                        Button(action: {
                            presentTextFieldAlert(
                                title: "Пожаловаться",
                                message: "Укажите причину жалобы:",
                                placeholder: "Причина жалобы"
                            ) { reason in
                                submitReport(reason: reason)
                            }
                        }) {
                            Text("Пожаловаться")
                                .font(.system(size: 12))
                                .foregroundColor(Color(.secondaryLabel))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func submitReport(reason: String) {
        let reasonText = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reasonText.isEmpty else { return }
        
        ReportsService.shared.addReport(ownerID: comment.id, type: "comment", comment: reasonText) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Report submitted successfully!")
                case .failure(let error):
                    print("Failed to submit report: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct MentionText: View {
    let text: String
    let onUserTap: (Int) -> Void

    var body: some View {
        if #available(iOS 15, *) {
            attributedBody
        } else {
            plainBody
        }
    }

    @available(iOS 15, *)
    private var attributedBody: some View {
        let attributed = makeAttributedString(from: text)
        return Text(attributed)
            .font(.system(size: 13))
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "openvk", let host = url.host, let id = Int(host) {
                    onUserTap(id)
                }
                return .handled
            })
            .fixedSize(horizontal: false, vertical: true)
    }

    private var plainBody: some View {
        let segments = parseMentions(text)
        return segments.reduce(Text("")) { result, segment in
            switch segment {
            case .text(let string):
                return result + Text(string).font(.system(size: 13)).foregroundColor(.primary)
            case .mention(_, let name):
                return result + Text(name).font(.system(size: 13)).foregroundColor(.appAccent)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @available(iOS 15, *)
    func makeAttributedString(from text: String) -> AttributedString {
        let pattern = try! NSRegularExpression(pattern: "\\[(id|club)(\\d+)\\|([^\\]]+)\\]")
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = pattern.matches(in: text, range: nsRange)

        var result = AttributedString(text)

        for match in matches.reversed() {
            guard let fullRange = Range(match.range(at: 0), in: text),
                  let typeRange = Range(match.range(at: 1), in: text),
                  let idRange = Range(match.range(at: 2), in: text),
                  let nameRange = Range(match.range(at: 3), in: text) else { continue }

            let type = text[typeRange]
            let idStr = text[idRange]
            let name = text[nameRange]
            let id = Int(idStr) ?? 0
            let resolvedId = type == "club" ? -id : id
            let fullStr = text[fullRange]

            if let attrRange = result.range(of: String(fullStr)) {
                result.replaceSubrange(attrRange, with: AttributedString(name))
                if let replacedRange = result.range(of: String(name)) {
                    result[replacedRange].foregroundColor = .appAccent
                    result[replacedRange].link = URL(string: "openvk://\(resolvedId)")
                }
            }
        }

        return result
    }

    enum Segment: Hashable {
        case text(String)
        case mention(id: Int, name: String)
    }

    func parseMentions(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var remaining = text
        let pattern = try! NSRegularExpression(pattern: "\\[(id|club)(\\d+)\\|([^\\]]+)\\]")

        while let match = pattern.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {
            let fullRange = Range(match.range(at: 0), in: remaining)!
            let prefix = remaining[remaining.startIndex..<fullRange.lowerBound]
            if !prefix.isEmpty {
                segments.append(.text(String(prefix)))
            }

            let type = remaining[Range(match.range(at: 1), in: remaining)!]
            let idStr = remaining[Range(match.range(at: 2), in: remaining)!]
            let name = remaining[Range(match.range(at: 3), in: remaining)!]
            let id = Int(idStr) ?? 0
            let resolvedId = type == "club" ? -id : id
            segments.append(.mention(id: resolvedId, name: String(name)))

            remaining = String(remaining[fullRange.upperBound...])
        }

        if !remaining.isEmpty {
            segments.append(.text(remaining))
        }

        return segments.isEmpty ? [.text(text)] : segments
    }
}

struct CommentAttachmentsView: View {
    let attachments: [Attachment]
    var onMediaTap: ((Attachment) -> Void)? = nil

    private var sortedAttachments: [Attachment] {
        let media = attachments.filter {
            switch $0 {
            case .image, .remoteImage, .video, .remoteVideo, .gif: return true
            default: return false
            }
        }
        let documents = attachments.filter {
            switch $0 {
            case .document: return true
            default: return false
            }
        }
        let others = attachments.filter {
            switch $0 {
            case .image, .remoteImage, .video, .remoteVideo, .gif, .document: return false
            default: return true
            }
        }
        return media + others + documents
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(sortedAttachments) { attachment in
                if case .document(let title, let ext, let size, let url) = attachment {
                    CommentDocumentAttachmentView(title: title, ext: ext, size: size, url: url)
                } else if case .gif(let title, let url) = attachment {
                    CommentGIFAttachmentView(title: title, url: url, onTap: {
                        onMediaTap?(attachment)
                    })
                } else {
                    Button(action: {
                        switch attachment {
                        case .remoteImage, .image, .remoteVideo, .video:
                            onMediaTap?(attachment)
                        default:
                            break
                        }
                    }) {
                        CommentAttachmentTile(attachment: attachment)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct CommentAttachmentTile: View {
    let attachment: Attachment

    var body: some View {
        switch attachment {
        case .remoteImage(let url, _, _, _, _, _, _):
            if let targetUrl = URL(string: url) {
                AsyncImage(url: targetUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: 200, maxHeight: 120)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        fallbackIcon("photo")
                    case .empty:
                        ProgressView()
                            .frame(width: 80, height: 80)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                fallbackIcon("photo")
            }

        case .remoteVideo(let title, let duration, _, _, _, _, _, _, _, _, _):
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.appAccent)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(duration)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)

        case .audio(let artist, let title, let duration):
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 12))
                    .foregroundColor(.appAccent)
                Text("\(artist) — \(title)")
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
                Text(duration)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)

        case .document:
            EmptyView()
        case .gif:
            EmptyView()

        default:
            EmptyView()
        }
    }

    func fallbackIcon(_ name: String) -> some View {
        ZStack {
            Color(.secondarySystemBackground)
            Image(systemName: name)
                .font(.system(size: 20))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .frame(width: 80, height: 80)
        .cornerRadius(8)
    }
}

struct CommentDocumentAttachmentView: View {
    let title: String
    let ext: String
    let size: String
    let url: String
    @State private var isDownloading = false

    var body: some View {
        Button(action: {
            DocumentDownloader.downloadAndShare(url: url, title: title, ext: ext, isDownloading: $isDownloading)
        }) {
            HStack(spacing: 8) {
                if isDownloading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(.appAccent)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                
                Spacer()
                
                Text(ext.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.appAccent)
                
                Text(size)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDownloading)
    }
}

struct CommentGIFAttachmentView: View {
    let title: String
    let url: String
    let onTap: () -> Void
    @State private var isDownloading = false

    var body: some View {
        ZStack {
            GIFView(urlString: url)
                .frame(width: 150, height: 100)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            
            if isDownloading {
                Color.black.opacity(0.3)
                    .frame(width: 150, height: 100)
                    .cornerRadius(8)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}


