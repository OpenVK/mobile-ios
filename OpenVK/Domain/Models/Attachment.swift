//
//  Attachment.swift
//  OpenVK for iOS
//
//  Типы вложений.
//

import Foundation

struct PollOption: Hashable, Identifiable {
    var id = UUID()
    let text: String
    var votes: Int
}

enum Attachment: Hashable, Identifiable {
    case image(systemName: String)
    case video(title: String, duration: String)
    case poll(question: String, options: [PollOption], totalVotes: Int)
    case document(title: String, ext: String, size: String, url: String)
    case gif(title: String, url: String)
    case audio(artist: String, title: String, duration: String)
    case note(title: String, content: String)
    case place(name: String, address: String)
    case remoteImage(url: String, id: Int?, ownerID: Int?, likesCount: Int, commentsCount: Int, repostsCount: Int, isLiked: Bool)
    case remoteVideo(title: String, duration: String, imageURL: String, videoURL: String?, id: Int?, ownerID: Int?, files: [String: String]?, likesCount: Int, commentsCount: Int, repostsCount: Int, isLiked: Bool)

    var id: String {
        switch self {
        case .image(let sys): return "image-\(sys)"
        case .video(let title, let dur): return "video-\(title)-\(dur)"
        case .poll(let q, _, _): return "poll-\(q)"
        case .document(let t, let ext, let s, let url): return "doc-\(t)-\(ext)-\(s)-\(url)"
        case .gif(let t, let url): return "gif-\(t)-\(url)"
        case .audio(let a, let t, let d): return "audio-\(a)-\(t)-\(d)"
        case .note(let t, let c): return "note-\(t)-\(c.prefix(10))"
        case .place(let n, let ad): return "place-\(n)-\(ad)"
        case .remoteImage(let url, let pid, _, _, _, _, _): return "remote-image-\(pid ?? 0)-\(url)"
        case .remoteVideo(let t, let d, let img, _, let vid, _, _, _, _, _, _): return "remote-video-\(vid ?? 0)-\(t)-\(d)-\(img)"
        }
    }
}
