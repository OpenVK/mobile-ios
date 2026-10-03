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

    var body: some View {
        ZStack {
            Circle()
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
                    .clipShape(Circle())
            } else {
                placeholder
                    .frame(width: size, height: size)
                    .clipShape(Circle())
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
        self.forceRefreshOnAppear = forceRefreshOnAppear
        self.refreshToken = refreshToken
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

    func load(from url: URL, forceRefresh: Bool = false) {
        let cachedImage = ImageCache.shared.image(for: url, maximumAge: avatarMaximumAge)
        let isSameURL = loadedURL == url

        if !forceRefresh, isSameURL, let cachedImage {
            image = cachedImage
            return
        }

        loadedURL = url
        if !forceRefresh || !isSameURL {
            image = cachedImage
        }
        guard forceRefresh || image == nil else { return }

        ImageCache.shared.load(
            url,
            maximumAge: avatarMaximumAge,
            forceRefresh: forceRefresh
        ) { [weak self] image in
            guard let self = self, self.loadedURL == url else { return }
            self.image = image
        }
    }
}
