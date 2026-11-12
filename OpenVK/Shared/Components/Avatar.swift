//
//  Avatar.swift
//  OpenVK for iOS
//

import SwiftUI

struct Avatar: View {
    let user: User
    var size: CGFloat = 42
    var refreshOnAppear = false
    var refreshToken: UUID?
    var placeholderImageName: String?
    var isChat = false

    private var avatarShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * (isChat ? 0.24 : 0.5), style: .continuous)
    }

    var body: some View {
        ZStack {
            avatarShape
                .fill(Color(.tertiarySystemFill))
                .frame(width: size, height: size)

            if let url = user.avatarURL {
                RemoteImage(
                    url: url,
                    forceRefreshOnAppear: refreshOnAppear,
                    refreshToken: refreshToken,
                    placeholder: { placeholder }
                )
                    .frame(width: size, height: size)
                    .clipShape(avatarShape)
            } else {
                placeholder
                    .frame(width: size, height: size)
                    .clipShape(avatarShape)
            }
        }
    }

    private var placeholder: some View {
        Group {
            if let placeholderImageName {
                Image(placeholderImageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
    }
}

struct RemoteImage<Placeholder: View>: View {
    let url: URL
    let placeholder: Placeholder
    var forceRefreshOnAppear = false
    var refreshToken: UUID?

    @StateObject private var loader = ImageLoader()

    init(
        url: URL,
        forceRefreshOnAppear: Bool = false,
        refreshToken: UUID? = nil,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
        self.forceRefreshOnAppear = forceRefreshOnAppear
        self.refreshToken = refreshToken
        self.placeholder = placeholder()
    }

    init(url: URL, placeholder: Placeholder) {
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
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
            loader.load(from: url, forceRefresh: forceRefreshOnAppear)
        }
        .onChange(of: url) { newUrl in
            loader.load(from: newUrl)
        }
        .onChange(of: refreshToken) { _ in
            loader.load(from: url, forceRefresh: true)
        }
    }
}

final class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    private var loadedURL: URL?
    private let avatarMaximumAge: TimeInterval = 60

    init(url: URL? = nil) {
        if let url {
            loadedURL = url
            image = ImageCache.shared.image(for: url, maximumAge: .greatestFiniteMagnitude)
        }
    }

    func load(from url: URL, forceRefresh: Bool = false) {
        let previousImage = ImageCache.shared.image(for: url, maximumAge: .greatestFiniteMagnitude)
        let cachedImage = ImageCache.shared.image(for: url, maximumAge: avatarMaximumAge)
        let isSameURL = loadedURL == url
        loadedURL = url
        if !isSameURL || image == nil {
            image = cachedImage ?? previousImage
        } else if let cachedImage {
            image = cachedImage
        }
        guard forceRefresh || cachedImage == nil else { return }

        ImageCache.shared.load(
            url,
            maximumAge: avatarMaximumAge,
            forceRefresh: forceRefresh
        ) { [weak self] image in
            guard let self, self.loadedURL == url, let image else { return }
            self.image = image
        }
    }
}
