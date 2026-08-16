//
//  Avatar.swift
//  OpenVK for iOS
//

import SwiftUI

struct Avatar: View {
    let user: User
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: size, height: size)

            if let url = user.avatarURL {
                RemoteImage(url: url, placeholder: placeholder)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: size * 0.5))
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
