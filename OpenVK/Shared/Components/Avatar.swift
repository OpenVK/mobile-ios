//
//  Avatar.swift
//  OpenVK for iOS
//

import SwiftUI

struct Avatar: View {
    let imageURL: URL?
    let placeholderSystemName: String
    var size: CGFloat = 42
    var isOnline: Bool? = nil

    init(user: User, size: CGFloat = 42) {
        self.imageURL = user.avatarURL
        self.placeholderSystemName = user.isGroup == true ? "person.2.fill" : "person.fill"
        self.size = size
        self.isOnline = user.isOnline
    }

    init(peer: Peer, size: CGFloat = 42) {
        self.imageURL = peer.avatarURL
        switch peer.type {
        case .chat:
            self.placeholderSystemName = "bubble.left.and.bubble.right.fill"
        case .group:
            self.placeholderSystemName = "person.2.fill"
        case .user:
            self.placeholderSystemName = "person.fill"
        }
        self.size = size
        self.isOnline = peer.isOnline
    }

    init(url: URL?, placeholderSystemName: String = "person.fill", size: CGFloat = 42, isOnline: Bool? = nil) {
        self.imageURL = url
        self.placeholderSystemName = placeholderSystemName
        self.size = size
        self.isOnline = isOnline
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: size, height: size)

                if let url = imageURL {
                    RemoteImage(url: url, placeholder: placeholder)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    placeholder
                }
            }

            if isOnline == true {
                Circle()
                    .fill(Color.green)
                    .frame(width: max(8, size * 0.24), height: max(8, size * 0.24))
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 1.5)
                    )
                    .offset(x: 1, y: 1)
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: placeholderSystemName)
            .font(.system(size: size * 0.45))
            .foregroundColor(Color(.secondaryLabel))
    }
}

struct RemoteImage<Placeholder: View>: View {
    let url: URL
    let placeholder: Placeholder

    @StateObject private var loader = ImageLoader()

    init(url: URL, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
    }

    init(url: URL, placeholder: Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .onAppear {
            loader.load(from: url)
        }
        .onChange(of: url) { newUrl in
            loader.load(from: newUrl)
        }
    }
}

final class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    private var task: URLSessionDataTask?
    private var loadedURL: URL?

    func load(from url: URL) {
        if loadedURL == url {
            return
        }
        
        task?.cancel()
        task = nil
        image = nil
        loadedURL = url
        
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data, let img = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.image = img
            }
        }
        task?.resume()
    }

    deinit {
        task?.cancel()
    }
}
