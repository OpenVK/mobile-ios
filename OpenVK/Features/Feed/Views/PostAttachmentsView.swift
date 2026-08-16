//
//  PostAttachmentsView.swift
//  OpenVK for iOS
//


import SwiftUI
import VLCKit
import Photos
import Combine

struct PostAttachmentsView: View {
    let attachments: [Attachment]
    var onMediaTap: ((Attachment) -> Void)? = nil

    private var photoAttachments: [Attachment] {
        attachments.filter {
            switch $0 {
            case .image, .remoteImage: return true
            default: return false
            }
        }
    }

    private var nonPhotoAttachments: [Attachment] {
        attachments.filter {
            switch $0 {
            case .image, .remoteImage: return false
            default: return true
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !photoAttachments.isEmpty {
                PhotoCollageView(photos: photoAttachments, onMediaTap: onMediaTap)
            }

            ForEach(nonPhotoAttachments) { attachment in
                if case .document(let title, let ext, let size, let url) = attachment {
                    DocumentAttachmentView(title: title, ext: ext, size: size, url: url)
                } else if case .gif(let title, let url) = attachment {
                    GIFAttachmentView(title: title, url: url, onTap: {
                        onMediaTap?(attachment)
                    })
                } else {
                    Button(action: {
                        switch attachment {
                        case .remoteVideo(_, _, _, _, _, _, _, _, _, _, _), .video(_, _):
                            onMediaTap?(attachment)
                        default:
                            break
                        }
                    }) {
                        view(for: attachment)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func view(for attachment: Attachment) -> some View {
        switch attachment {
        case .image(let sysName):
            ImageAttachmentView(systemName: sysName)
        case .video(let title, let duration):
            VideoAttachmentView(title: title, duration: duration, imageURL: nil)
        case .remoteImage(let url, _, _, _, _, _, _):
            RemoteImageAttachmentView(url: url)
        case .remoteVideo(let title, let duration, let imageURL, _, _, _, _, _, _, _, _):
            VideoAttachmentView(title: title, duration: duration, imageURL: imageURL)
        case .poll(let question, let options, let totalVotes):
            PollAttachmentView(question: question, options: options, totalVotes: totalVotes)
        case .document(let title, let ext, let size, let url):
            DocumentAttachmentView(title: title, ext: ext, size: size, url: url)
        case .gif(let title, let url):
            GIFAttachmentView(title: title, url: url, onTap: {})
        case .audio(let artist, let title, let duration):
            AudioAttachmentView(artist: artist, title: title, duration: duration)
        case .note(let title, let content):
            NoteAttachmentView(title: title, content: content)
        case .place(let name, let address):
            PlaceAttachmentView(name: name, address: address)
        }
    }
}

struct PhotoCollageView: View {
    let photos: [Attachment]
    var onMediaTap: ((Attachment) -> Void)? = nil

    var body: some View {
        Group {
            switch photos.count {
            case 0:
                EmptyView()
            case 1:
                singlePhoto(photos[0])
            case 2:
                twoPhotosLayout(photos)
            case 3:
                threePhotosLayout(photos)
            case 4:
                fourPhotosLayout(photos)
            case 5:
                fivePhotosLayout(photos)
            case 6:
                sixPhotosLayout(photos)
            case 7:
                sevenPhotosLayout(photos)
            case 8:
                eightPhotosLayout(photos)
            case 9:
                ninePhotosLayout(photos)
            default:
                generalGridCollage(photos)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .cornerRadius(12)
    }

    @ViewBuilder
    private func singlePhoto(_ attachment: Attachment) -> some View {
        Button(action: { onMediaTap?(attachment) }) {
            if case .remoteImage(let urlString, _, _, _, _, _, _) = attachment,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 380)
                            .cornerRadius(12)
                            .contentShape(Rectangle())
                    case .failure:
                        ImageAttachmentView(systemName: "photo")
                    case .empty:
                        ZStack {
                            Color(.secondarySystemBackground)
                            ProgressView()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .cornerRadius(12)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if case .image(let sysName) = attachment {
                ImageAttachmentView(systemName: sysName)
            } else {
                EmptyView()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func twoPhotosLayout(_ items: [Attachment]) -> some View {
        HStack(spacing: 4) {
            CollageImageView(attachment: items[0]) { onMediaTap?(items[0]) }
            CollageImageView(attachment: items[1]) { onMediaTap?(items[1]) }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
    }

    @ViewBuilder
    private func threePhotosLayout(_ items: [Attachment]) -> some View {
        HStack(spacing: 4) {
            CollageImageView(attachment: items[0]) { onMediaTap?(items[0]) }
            
            VStack(spacing: 4) {
                CollageImageView(attachment: items[1]) { onMediaTap?(items[1]) }
                CollageImageView(attachment: items[2]) { onMediaTap?(items[2]) }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 230)
    }

    @ViewBuilder
    private func fourPhotosLayout(_ items: [Attachment]) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                CollageImageView(attachment: items[0]) { onMediaTap?(items[0]) }
                CollageImageView(attachment: items[1]) { onMediaTap?(items[1]) }
            }
            HStack(spacing: 4) {
                CollageImageView(attachment: items[2]) { onMediaTap?(items[2]) }
                CollageImageView(attachment: items[3]) { onMediaTap?(items[3]) }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
    }

    @ViewBuilder
    private func fivePhotosLayout(_ items: [Attachment]) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                CollageImageView(attachment: items[0]) { onMediaTap?(items[0]) }
                CollageImageView(attachment: items[1]) { onMediaTap?(items[1]) }
            }
            .frame(height: 140)
            
            HStack(spacing: 4) {
                CollageImageView(attachment: items[2]) { onMediaTap?(items[2]) }
                CollageImageView(attachment: items[3]) { onMediaTap?(items[3]) }
                CollageImageView(attachment: items[4]) { onMediaTap?(items[4]) }
            }
            .frame(height: 110)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 254)
    }

    @ViewBuilder
    private func sixPhotosLayout(_ items: [Attachment]) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                CollageImageView(attachment: items[0]) { onMediaTap?(items[0]) }
                CollageImageView(attachment: items[1]) { onMediaTap?(items[1]) }
                CollageImageView(attachment: items[2]) { onMediaTap?(items[2]) }
            }
            HStack(spacing: 4) {
                CollageImageView(attachment: items[3]) { onMediaTap?(items[3]) }
                CollageImageView(attachment: items[4]) { onMediaTap?(items[4]) }
                CollageImageView(attachment: items[5]) { onMediaTap?(items[5]) }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
    }

    @ViewBuilder
    private func sevenPhotosLayout(_ items: [Attachment]) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                CollageImageView(attachment: items[0]) { onMediaTap?(items[0]) }
                CollageImageView(attachment: items[1]) { onMediaTap?(items[1]) }
                CollageImageView(attachment: items[2]) { onMediaTap?(items[2]) }
            }
            .frame(height: 110)
            
            HStack(spacing: 4) {
                CollageImageView(attachment: items[3]) { onMediaTap?(items[3]) }
                CollageImageView(attachment: items[4]) { onMediaTap?(items[4]) }
            }
            .frame(height: 110)

            HStack(spacing: 4) {
                CollageImageView(attachment: items[5]) { onMediaTap?(items[5]) }
                CollageImageView(attachment: items[6]) { onMediaTap?(items[6]) }
            }
            .frame(height: 110)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 338)
    }

    @ViewBuilder
    private func eightPhotosLayout(_ items: [Attachment]) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<4) { idx in
                    CollageImageView(attachment: items[idx]) { onMediaTap?(items[idx]) }
                }
            }
            .frame(height: 90)
            
            HStack(spacing: 4) {
                ForEach(4..<8) { idx in
                    CollageImageView(attachment: items[idx]) { onMediaTap?(items[idx]) }
                }
            }
            .frame(height: 90)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 184)
    }

    @ViewBuilder
    private func ninePhotosLayout(_ items: [Attachment]) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<3) { idx in
                    CollageImageView(attachment: items[idx]) { onMediaTap?(items[idx]) }
                }
            }
            .frame(height: 95)
            
            HStack(spacing: 4) {
                ForEach(3..<6) { idx in
                    CollageImageView(attachment: items[idx]) { onMediaTap?(items[idx]) }
                }
            }
            .frame(height: 95)

            HStack(spacing: 4) {
                ForEach(6..<9) { idx in
                    CollageImageView(attachment: items[idx]) { onMediaTap?(items[idx]) }
                }
            }
            .frame(height: 95)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 293)
    }

    @ViewBuilder
    private func generalGridCollage(_ items: [Attachment]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(items) { item in
                CollageImageView(attachment: item) {
                    onMediaTap?(item)
                }
                .frame(height: 95)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CollageImageView: View {
    let attachment: Attachment
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geo in
                ZStack {
                    Color(.secondarySystemBackground)
                    
                    switch attachment {
                    case .remoteImage(let urlString, _, _, _, _, _, _):
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .clipped()
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(.tertiaryLabel))
                                case .empty:
                                    ProgressView()
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    case .image(let sysName):
                        Image(systemName: sysName)
                            .font(.system(size: 28))
                            .foregroundColor(Color(.tertiaryLabel))
                    default:
                        EmptyView()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RemoteImageAttachmentView: View {
    let url: String

    var body: some View {
        Group {
            if let targetUrl = URL(string: url) {
                AsyncImage(url: targetUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 400)
                            .cornerRadius(12)
                            .contentShape(Rectangle())
                    case .failure:
                        ImageAttachmentView(systemName: "photo")
                    case .empty:
                        ZStack {
                            Color(.secondarySystemBackground)
                            ProgressView()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .cornerRadius(12)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                ImageAttachmentView(systemName: "photo")
            }
        }
    }
}

struct ImageAttachmentView: View {
    let systemName: String

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 36))
                    .foregroundColor(Color(.tertiaryLabel))
                Text("Фотография")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .cornerRadius(12)
    }
}

struct VideoAttachmentView: View {
    let title: String
    let duration: String
    let imageURL: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let urlString = imageURL, !urlString.isEmpty, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.black.opacity(0.85)
                    }
                } else {
                    Color.black.opacity(0.85)
                }
                
                Color.black.opacity(0.35)
                
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                            .offset(x: 2)
                    )
                
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "video.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(10)
                    .background(LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.6)]), startPoint: .top, endPoint: .bottom))
                }
            }
            
            Text(duration)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.75))
                .cornerRadius(4)
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipped()
        .cornerRadius(12)
        .contentShape(Rectangle())
    }
}

struct PollAttachmentView: View {
    let question: String
    let options: [PollOption]
    let totalVotes: Int
    @State private var votedOptionId: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.square.fill")
                    .foregroundColor(.appAccent)
                    .font(.system(size: 14))
                Text("Опрос")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Text(question)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)

            ForEach(options) { option in
                let isThisVoted = votedOptionId == option.id
                let displayVotes = option.votes + (isThisVoted ? 1 : 0)
                let displayTotal = totalVotes + (votedOptionId != nil ? 1 : 0)
                let percent = displayTotal > 0 ? Int(Double(displayVotes) / Double(displayTotal) * 100) : 0

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if votedOptionId == option.id {
                            votedOptionId = nil
                        } else {
                            votedOptionId = option.id
                        }
                    }
                }) {
                    ZStack(alignment: .leading) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isThisVoted ? Color.appAccent.opacity(0.15) : Color(.secondarySystemBackground))
                                .frame(width: geo.size.width)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isThisVoted ? Color.appAccent.opacity(0.3) : Color(.systemGray5))
                                .frame(width: geo.size.width * CGFloat(percent) / 100)
                        }

                        HStack {
                            Text(option.text)
                                .font(.system(size: 14, weight: isThisVoted ? .medium : .regular))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(percent)%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(height: 38)
            }

            Text("Проголосовало: \(totalVotes + (votedOptionId != nil ? 1 : 0))")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
                .background(Color(.systemBackground))
        )
    }
}

struct DocumentAttachmentView: View {
    let title: String
    let ext: String
    let size: String
    let url: String
    
    @State private var isDownloading = false

    var body: some View {
        Button(action: {
            DocumentDownloader.downloadAndShare(url: url, title: title, ext: ext, isDownloading: $isDownloading)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appAccent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.appAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(ext.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.appAccent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.appAccent.opacity(0.15))
                            .cornerRadius(3)
                        
                        Text(size)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isDownloading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDownloading)
    }
}

struct AudioAttachmentView: View {
    let artist: String
    let title: String
    let duration: String
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isPlaying.toggle() }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.appAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(duration)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct NoteAttachmentView: View {
    let title: String
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "note.text")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(content)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct PlaceAttachmentView: View {
    let name: String
    let address: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Text("\(name), \(address)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct MediaFullScreenViewer: View {
    let post: Post
    let attachments: [Attachment]
    let initialSelectedIndex: Int
    
    var onLikeToggle: () -> Void
    var onCommentTap: () -> Void
    var onDismiss: () -> Void
    
    @State private var selectedIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var activeAlertMessage: String? = nil
    @State private var showAlert = false
    @State private var selectedQuality: String = "Auto"
    @State private var currentAttachments: [Attachment] = []
    @State private var showCommentsSheet = false

    init(post: Post, attachments: [Attachment], initialSelectedIndex: Int, onLikeToggle: @escaping () -> Void, onCommentTap: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.post = post
        self.attachments = attachments
        self.initialSelectedIndex = initialSelectedIndex
        self.onLikeToggle = onLikeToggle
        self.onCommentTap = onCommentTap
        self.onDismiss = onDismiss
        _selectedIndex = State(initialValue: initialSelectedIndex)
        _currentAttachments = State(initialValue: attachments)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .opacity(Double(1.0 - min(1.0, max(0.0, dragOffset.height / 300.0))))
            
            TabView(selection: $selectedIndex) {
                ForEach(0..<currentAttachments.count, id: \.self) { idx in
                    mediaView(for: currentAttachments[idx])
                        .tag(idx)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: selectedIndex) { newIndex in
                updateSelectedQualityForCurrentMedia()
            }
            .onAppear {
                updateSelectedQualityForCurrentMedia()
            }
            
            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .statusBar(hidden: true)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Сохранение"), message: Text(activeAlertMessage ?? ""), dismissButton: .default(Text("ОК")))
        }
        .sheet(isPresented: $showCommentsSheet) {
            if let type = currentMediaType, let owner = currentMediaOwnerID, let id = currentMediaID {
                MediaCommentsView(mediaType: type, ownerID: owner, mediaID: id) {
                    incrementCurrentMediaCommentsCount()
                }
            } else {
                Text("Комментарии недоступны для этого вложения")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    @ViewBuilder
    private func mediaView(for attachment: Attachment) -> some View {
        switch attachment {
        case .remoteImage(let urlString, _, _, _, _, _, _):
            if let url = URL(string: urlString) {
                ZoomableScrollView(dragOffset: $dragOffset, onDismiss: onDismiss) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            placeholderImage
                        case .empty:
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: dragOffset.height)
            } else {
                placeholderImage
            }
        case .image(let sysName):
            ZoomableScrollView(dragOffset: $dragOffset, onDismiss: onDismiss) {
                Image(systemName: sysName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 200)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: dragOffset.height)
        case .remoteVideo(let title, _, let imageURL, let videoURL, _, _, let files, _, _, _, _):
            DismissableContainer(dragOffset: $dragOffset, onDismiss: onDismiss) {
                FullScreenVideoPlayerView(
                    title: title,
                    coverURLString: imageURL,
                    videoURLString: videoURL,
                    files: files,
                    selectedQuality: $selectedQuality,
                    isActive: selectedIndex == currentAttachments.firstIndex(of: attachment)
                )
            }
            .offset(y: dragOffset.height)
        case .gif(_, let urlString):
            ZoomableScrollView(dragOffset: $dragOffset, onDismiss: onDismiss) {
                GIFView(urlString: urlString)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: dragOffset.height)
        default:
            EmptyView()
        }
    }
    
    private var placeholderImage: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("Не удалось загрузить изображение")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            
            Spacer()
            
            Menu {
                if selectedIndex < currentAttachments.count,
                   case .remoteVideo(_, _, _, _, _, _, let files, _, _, _, _) = currentAttachments[selectedIndex],
                   let filesDict = files, !filesDict.isEmpty {
                    
                    Menu("Качество") {
                        ForEach(qualities(for: filesDict), id: \.self) { qual in
                            Button(action: {
                                selectedQuality = qual
                            }) {
                                HStack {
                                    Text(qual.replacingOccurrences(of: "mp4_", with: "") + "p")
                                    if qual == selectedQuality {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }

                if isCurrentImage {
                    Button(action: downloadCurrentImage) {
                        Label("Скачать в галерею", systemImage: "square.and.arrow.down")
                    }
                }
                
                if selectedIndex < currentAttachments.count,
                   case .remoteVideo(_, _, _, let videoURLStr, _, _, _, _, _, _, _) = currentAttachments[selectedIndex],
                   let urlStr = videoURLStr, let url = URL(string: urlStr) {
                    Button(action: {
                        UIApplication.shared.open(url)
                    }) {
                        Label("Открыть в браузере", systemImage: "safari")
                    }
                }
                
                Button(action: shareCurrentMedia) {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 12)
    }
    
    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Avatar(user: post.author, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(post.author.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if post.author.isOfficial == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.appAccent)
                        }
                        SupporterBadgeView(screenName: post.author.username)
                    }
                    Text(post.timeAgo)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
                
                Text("\(selectedIndex + 1) из \(currentAttachments.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            
            if !post.text.isEmpty {
                Text(post.text)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    toggleAttachmentLike()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isCurrentMediaLiked ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isCurrentMediaLiked ? .red : .white)
                        if currentMediaLikesCount > 0 {
                            Text("\(currentMediaLikesCount)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.18))
                    .cornerRadius(20)
                }
                
                Button(action: {
                    showCommentsSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        if currentMediaCommentsCount > 0 {
                            Text("\(currentMediaCommentsCount)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.18))
                    .cornerRadius(20)
                }
                
                Button(action: {
                    shareCurrentMedia()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrowshape.turn.up.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        if currentMediaRepostsCount > 0 {
                            Text("\(currentMediaRepostsCount)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.18))
                    .cornerRadius(20)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 30)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var isCurrentImage: Bool {
        guard selectedIndex < currentAttachments.count else { return false }
        switch currentAttachments[selectedIndex] {
        case .remoteImage, .image, .gif: return true
        default: return false
        }
    }
    
    private var isCurrentMediaLiked: Bool {
        guard selectedIndex < currentAttachments.count else { return false }
        switch currentAttachments[selectedIndex] {
        case .remoteImage(_, _, _, _, _, _, let liked): return liked
        case .remoteVideo(_, _, _, _, _, _, _, _, _, _, let liked): return liked
        default: return false
        }
    }
    
    private var currentMediaLikesCount: Int {
        guard selectedIndex < currentAttachments.count else { return 0 }
        switch currentAttachments[selectedIndex] {
        case .remoteImage(_, _, _, let likes, _, _, _): return likes
        case .remoteVideo(_, _, _, _, _, _, _, let likes, _, _, _): return likes
        default: return 0
        }
    }
    
    private var currentMediaCommentsCount: Int {
        guard selectedIndex < currentAttachments.count else { return 0 }
        switch currentAttachments[selectedIndex] {
        case .remoteImage(_, _, _, _, let comments, _, _): return comments
        case .remoteVideo(_, _, _, _, _, _, _, _, let comments, _, _): return comments
        default: return 0
        }
    }
    
    private var currentMediaRepostsCount: Int {
        guard selectedIndex < currentAttachments.count else { return 0 }
        switch currentAttachments[selectedIndex] {
        case .remoteImage(_, _, _, _, _, let reposts, _): return reposts
        case .remoteVideo(_, _, _, _, _, _, _, _, _, let reposts, _): return reposts
        default: return 0
        }
    }
    
    private var currentMediaID: Int? {
        guard selectedIndex < currentAttachments.count else { return nil }
        switch currentAttachments[selectedIndex] {
        case .remoteImage(_, let id, _, _, _, _, _): return id
        case .remoteVideo(_, _, _, _, let id, _, _, _, _, _, _): return id
        default: return nil
        }
    }
    
    private var currentMediaOwnerID: Int? {
        guard selectedIndex < currentAttachments.count else { return nil }
        switch currentAttachments[selectedIndex] {
        case .remoteImage(_, _, let owner, _, _, _, _): return owner
        case .remoteVideo(_, _, _, _, _, let owner, _, _, _, _, _): return owner
        default: return nil
        }
    }
    
    private var currentMediaType: String? {
        guard selectedIndex < currentAttachments.count else { return nil }
        switch currentAttachments[selectedIndex] {
        case .remoteImage: return "photo"
        case .remoteVideo: return "video"
        default: return nil
        }
    }
    
    private func incrementCurrentMediaCommentsCount() {
        guard selectedIndex < currentAttachments.count else { return }
        let current = currentAttachments[selectedIndex]
        switch current {
        case .remoteImage(let url, let id, let owner, let likes, let comments, let reposts, let liked):
            currentAttachments[selectedIndex] = .remoteImage(
                url: url,
                id: id,
                ownerID: owner,
                likesCount: likes,
                commentsCount: comments + 1,
                repostsCount: reposts,
                isLiked: liked
            )
        case .remoteVideo(let title, let duration, let imageURL, let videoURL, let id, let owner, let files, let likes, let comments, let reposts, let liked):
            currentAttachments[selectedIndex] = .remoteVideo(
                title: title,
                duration: duration,
                imageURL: imageURL,
                videoURL: videoURL,
                id: id,
                ownerID: owner,
                files: files,
                likesCount: likes,
                commentsCount: comments + 1,
                repostsCount: reposts,
                isLiked: liked
            )
        default:
            break
        }
    }
    
    private func updateSelectedQualityForCurrentMedia() {
        guard selectedIndex < currentAttachments.count else { return }
        if case .remoteVideo(_, _, _, _, _, _, let files, _, _, _, _) = currentAttachments[selectedIndex],
           let filesDict = files, !filesDict.isEmpty {
            let sortedKeys = filesDict.keys.sorted { key1, key2 in
                let val1 = Int(key1.replacingOccurrences(of: "mp4_", with: "")) ?? 0
                let val2 = Int(key2.replacingOccurrences(of: "mp4_", with: "")) ?? 0
                return val1 > val2
            }
            if let first = sortedKeys.first {
                selectedQuality = first
            }
        } else {
            selectedQuality = "Auto"
        }
    }
    
    private func qualities(for files: [String: String]) -> [String] {
        files.keys.sorted { key1, key2 in
            let val1 = Int(key1.replacingOccurrences(of: "mp4_", with: "")) ?? 0
            let val2 = Int(key2.replacingOccurrences(of: "mp4_", with: "")) ?? 0
            return val1 > val2
        }
    }
    
    private func toggleAttachmentLike() {
        guard selectedIndex < currentAttachments.count else { return }
        let current = currentAttachments[selectedIndex]
        
        let typeString: String
        let itemID: Int?
        let ownerID: Int?
        let isLiked: Bool
        
        switch current {
        case .remoteImage(let url, let id, let owner, let likes, let comments, let reposts, let liked):
            typeString = "photo"
            itemID = id
            ownerID = owner
            isLiked = liked
        case .remoteVideo(let title, let duration, let imageURL, let videoURL, let id, let owner, let files, let likes, let comments, let reposts, let liked):
            typeString = "video"
            itemID = id
            ownerID = owner
            isLiked = liked
        default:
            return
        }
        
        updateAttachmentLikeState(selectedIndex: selectedIndex, isLiked: !isLiked)
        
        guard let item = itemID, let owner = ownerID else {
            return
        }
        
        let method = isLiked ? "likes.delete" : "likes.add"
        let params: [String: String] = [
            "type": typeString,
            "owner_id": "\(owner)",
            "item_id": "\(item)"
        ]
        
        APIClient.shared.call(
            method: method,
            parameters: params,
            httpMethod: "POST",
            as: VKLikesCountResponse.self
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let count = response.likes {
                        updateAttachmentLikeCount(selectedIndex: selectedIndex, count: count)
                    }
                case .failure(let error):
                    updateAttachmentLikeState(selectedIndex: selectedIndex, isLiked: isLiked)
                    print("Failed to toggle like: \(error)")
                }
            }
        }
    }
    
    private func updateAttachmentLikeState(selectedIndex: Int, isLiked: Bool) {
        guard selectedIndex < currentAttachments.count else { return }
        let current = currentAttachments[selectedIndex]
        switch current {
        case .remoteImage(let url, let id, let owner, var likes, let comments, let reposts, let liked):
            let diff = isLiked ? 1 : -1
            likes = max(0, likes + diff)
            currentAttachments[selectedIndex] = .remoteImage(
                url: url,
                id: id,
                ownerID: owner,
                likesCount: likes,
                commentsCount: comments,
                repostsCount: reposts,
                isLiked: isLiked
            )
        case .remoteVideo(let title, let duration, let imageURL, let videoURL, let id, let owner, let files, var likes, let comments, let reposts, let liked):
            let diff = isLiked ? 1 : -1
            likes = max(0, likes + diff)
            currentAttachments[selectedIndex] = .remoteVideo(
                title: title,
                duration: duration,
                imageURL: imageURL,
                videoURL: videoURL,
                id: id,
                ownerID: owner,
                files: files,
                likesCount: likes,
                commentsCount: comments,
                repostsCount: reposts,
                isLiked: isLiked
            )
        default:
            break
        }
    }
    
    private func updateAttachmentLikeCount(selectedIndex: Int, count: Int) {
        guard selectedIndex < currentAttachments.count else { return }
        let current = currentAttachments[selectedIndex]
        switch current {
        case .remoteImage(let url, let id, let owner, _, let comments, let reposts, let liked):
            currentAttachments[selectedIndex] = .remoteImage(
                url: url,
                id: id,
                ownerID: owner,
                likesCount: count,
                commentsCount: comments,
                repostsCount: reposts,
                isLiked: liked
            )
        case .remoteVideo(let title, let duration, let imageURL, let videoURL, let id, let owner, let files, _, let comments, let reposts, let liked):
            currentAttachments[selectedIndex] = .remoteVideo(
                title: title,
                duration: duration,
                imageURL: imageURL,
                videoURL: videoURL,
                id: id,
                ownerID: owner,
                files: files,
                likesCount: count,
                commentsCount: comments,
                repostsCount: reposts,
                isLiked: liked
            )
        default:
            break
        }
    }
    
    private func downloadCurrentImage() {
        guard selectedIndex < currentAttachments.count else { return }
        let current = currentAttachments[selectedIndex]
        
        if case .remoteImage(let urlString, _, _, _, _, _, _) = current, let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    let saver = ImageSaver()
                    saver.writeToPhotoAlbum(image: image) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.activeAlertMessage = "Фотография сохранена в вашу фотопленку."
                            } else {
                                self.activeAlertMessage = "Не удалось сохранить фото: \(error?.localizedDescription ?? "неизвестная ошибка")"
                            }
                            self.showAlert = true
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.activeAlertMessage = "Не удалось загрузить данные изображения."
                        self.showAlert = true
                    }
                }
            }.resume()
        } else if case .gif(_, let urlString) = current, let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetCreationRequest.forAsset()
                        request.addResource(with: .photo, data: data, options: nil)
                    }) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.activeAlertMessage = "GIF сохранена в вашу фотопленку."
                            } else {
                                self.activeAlertMessage = "Не удалось сохранить GIF: \(error?.localizedDescription ?? "неизвестная ошибка")"
                            }
                            self.showAlert = true
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.activeAlertMessage = "Не удалось загрузить GIF."
                        self.showAlert = true
                    }
                }
            }.resume()
        }
    }
    
    private func shareCurrentMedia() {
        guard selectedIndex < currentAttachments.count else { return }
        let current = currentAttachments[selectedIndex]
        
        var shareItem: Any? = nil
        
        switch current {
        case .remoteImage(let urlString, _, _, _, _, _, _):
            shareItem = URL(string: urlString)
        case .gif(_, let urlString):
            shareItem = URL(string: urlString)
        case .remoteVideo(_, _, _, let videoURLString, _, _, _, _, _, _, _):
            shareItem = videoURLString.flatMap { URL(string: $0) }
        case .image(let sysName):
            shareItem = sysName
        default:
            break
        }
        
        guard let item = shareItem else { return }
        
        let av = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        
        if let topVC = getTopmostViewController() {
            if let popover = av.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topVC.present(av, animated: true, completion: nil)
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void
    
    @GestureState private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 4)
                
                Capsule()
                    .fill(Color.appAccent)
                    .frame(width: width * min(1.0, max(0.0, percentage)), height: 4)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 14 : 10, height: isDragging ? 14 : 10)
                    .shadow(radius: 2)
                    .offset(x: (width - 10) * min(1.0, max(0.0, percentage)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { gesture in
                        onEditingChanged(true)
                        let rawLocation = gesture.location.x
                        let relativeLocation = min(1.0, max(0.0, rawLocation / width))
                        let newValue = range.lowerBound + Double(relativeLocation) * (range.upperBound - range.lowerBound)
                        value = newValue
                    }
                    .onEnded { _ in
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 14)
    }
}

struct DismissableContainer<Content: View>: UIViewRepresentable {
    let content: Content
    @Binding var dragOffset: CGSize
    var onDismiss: () -> Void

    init(dragOffset: Binding<CGSize>, onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.content = content()
        self._dragOffset = dragOffset
        self.onDismiss = onDismiss
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .clear
        scrollView.isScrollEnabled = false

        let hostedView = UIHostingController(rootView: content)
        hostedView.view.translatesAutoresizingMaskIntoConstraints = false
        hostedView.view.backgroundColor = .clear
        scrollView.addSubview(hostedView.view)

        NSLayoutConstraint.activate([
            hostedView.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedView.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hostedView.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.hostedView = hostedView
        context.coordinator.dragOffset = _dragOffset
        context.coordinator.onDismiss = onDismiss

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        scrollView.addGestureRecognizer(pan)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostedView?.rootView = content
        context.coordinator.dragOffset = _dragOffset
        context.coordinator.onDismiss = onDismiss
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var hostedView: UIHostingController<Content>?
        var dragOffset: Binding<CGSize>?
        var onDismiss: (() -> Void)?

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            let translation = gesture.translation(in: scrollView)
            
            switch gesture.state {
            case .changed:
                if translation.y > 0 {
                    dragOffset?.wrappedValue = CGSize(width: translation.x, height: translation.y)
                }
            case .ended, .cancelled:
                if translation.y > 100 {
                    withAnimation(.easeOut(duration: 0.25)) {
                        dragOffset?.wrappedValue = CGSize(width: 0, height: UIScreen.main.bounds.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self.onDismiss?()
                    }
                } else {
                    withAnimation(.spring()) {
                        dragOffset?.wrappedValue = .zero
                    }
                }
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let scrollView = pan.view as? UIScrollView else { return true }
            
            let velocity = pan.velocity(in: scrollView)
            return velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
        }
    }
}

struct PlayerContainerView: UIViewRepresentable {
    let player: VLCMediaPlayer
    let url: URL
    let shouldPlay: Bool
    @Binding var isLoading: Bool
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isDraggingSlider: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        player.drawable = view
        player.delegate = context.coordinator
        
        if let media = VLCMedia(url: url) {
            // Add options for better caching and streaming performance
            media.addOption("--network-caching=2000")
            player.media = media
            if shouldPlay {
                activateAudioSession()
                player.play()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        if let currentMedia = player.media, currentMedia.url != url {
            if let media = VLCMedia(url: url) {
                media.addOption("--network-caching=2000")
                player.media = media
                activateAudioSession()
                player.play()
            }
        }
    }

    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }
    
    class Coordinator: NSObject, VLCMediaPlayerDelegate {
        var parent: PlayerContainerView
        
        init(parent: PlayerContainerView) {
            self.parent = parent
        }
        
        func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
            DispatchQueue.main.async {
                switch newState {
                case .opening, .nothingSpecial:
                    self.parent.isLoading = true
                case .playing:
                    self.parent.isLoading = false
                    self.parent.isPlaying = true
                case .paused:
                    self.parent.isLoading = false
                    self.parent.isPlaying = false
                case .stopped, .stopping, .error:
                    self.parent.isLoading = false
                    self.parent.isPlaying = false
                @unknown default:
                    break
                }
            }
        }

        func mediaPlayerBufferingChanged(_ progress: Float) {
            DispatchQueue.main.async {
                self.parent.isLoading = progress < 1.0
            }
        }
        
        func mediaPlayerTimeChanged(_ aNotification: Notification) {
            guard let player = aNotification.object as? VLCMediaPlayer else { return }
            DispatchQueue.main.async {
                if !self.parent.isDraggingSlider {
                    self.parent.currentTime = Double(player.time.value?.doubleValue ?? 0) / 1000.0
                    if let media = player.media {
                        self.parent.duration = Double(media.length.value?.doubleValue ?? 0) / 1000.0
                    }
                }
            }
        }
    }
}

struct FullScreenVideoPlayerView: View {
    let title: String
    let coverURLString: String
    let videoURLString: String?
    let files: [String: String]?
    @Binding var selectedQuality: String
    let isActive: Bool
    
    @State private var player: VLCMediaPlayer?
    @State private var isPlaying = false
    
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isDraggingSlider = false
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player, let urlStr = getActiveURLString(), let url = URL(string: urlStr) {
                ZStack {
                    PlayerContainerView(
                        player: player,
                        url: url,
                        shouldPlay: isActive,
                        isLoading: $isLoading,
                        isPlaying: $isPlaying,
                        currentTime: $currentTime,
                        duration: $duration,
                        isDraggingSlider: $isDraggingSlider
                    )
                    .onTapGesture {
                        togglePlayPause()
                    }
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(10)
                    }
                }
                
                if !isPlaying {
                    Button(action: togglePlayPause) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.85))
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                }
                
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Text(formatTime(currentTime))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 45, alignment: .leading)
                        
                        CustomSlider(value: Binding(
                            get: { currentTime },
                            set: { newValue in
                                currentTime = newValue
                                seek(to: newValue)
                            }
                        ), range: 0...max(1, duration)) { dragging in
                            isDraggingSlider = dragging
                        }
                        
                        Text(formatTime(duration))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 45, alignment: .trailing)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 160)
                }
            } else {
                ZStack {
                    if let imgUrl = URL(string: coverURLString) {
                        AsyncImage(url: imgUrl) { img in
                            img.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.black
                        }
                    } else {
                        Color.black
                    }
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            teardownPlayer()
        }
        .onChange(of: isActive) { active in
            if active {
                ensureAudioSessionActive()
                player?.play()
                player?.audio?.volume = 100
                player?.audio?.isMuted = false
                isPlaying = true
            } else {
                player?.pause()
                isPlaying = false
            }
        }
        .onChange(of: selectedQuality) { newQuality in
            selectQuality(newQuality)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "00:00" }
        let sec = Int(seconds) % 60
        let min = (Int(seconds) / 60) % 60
        let hr = Int(seconds) / 3600
        if hr > 0 {
            return String(format: "%d:%02d:%02d", hr, min, sec)
        } else {
            return String(format: "%02d:%02d", min, sec)
        }
    }
    
    private func ensureAudioSessionActive() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to activate audio session with moviePlayback: \(error)")
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    private func togglePlayPause() {
        guard let player = player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            ensureAudioSessionActive()
            player.play()
            player.audio?.volume = 100
            player.audio?.isMuted = false
            isPlaying = true
        }
    }
    
    private func setupPlayer() {
        let newPlayer = VLCMediaPlayer()
        self.player = newPlayer
        
        isLoading = true
    }
    
    private func seek(to seconds: Double) {
        guard let player = player else { return }
        player.time = VLCTime(int: Int32(seconds * 1000))
    }
    
    private func getActiveURLString() -> String? {
        if let filesDict = files, let chosenUrl = filesDict[selectedQuality] {
            return chosenUrl
        }
        return videoURLString
    }
    
    private func selectQuality(_ quality: String) {
        isLoading = true
    }
    
    private func teardownPlayer() {
        player?.stop()
        player = nil
        isPlaying = false
    }
}

class ImageSaver: NSObject {
    var completion: ((Bool, Error?) -> Void)?

    func writeToPhotoAlbum(image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        self.completion = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            completion?(false, error)
        } else {
            completion?(true, nil)
        }
    }
}

func getTopmostViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          var topVC = windowScene.windows.first?.rootViewController else {
        return nil
    }
    while let presentedVC = topVC.presentedViewController {
        topVC = presentedVC
    }
    return topVC
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    @Binding var dragOffset: CGSize
    var onDismiss: () -> Void

    init(dragOffset: Binding<CGSize>, onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.content = content()
        self._dragOffset = dragOffset
        self.onDismiss = onDismiss
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .clear
        scrollView.isScrollEnabled = false

        let hostedView = UIHostingController(rootView: content)
        hostedView.view.translatesAutoresizingMaskIntoConstraints = false
        hostedView.view.backgroundColor = .clear
        scrollView.addSubview(hostedView.view)

        NSLayoutConstraint.activate([
            hostedView.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedView.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hostedView.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.hostedView = hostedView
        context.coordinator.dragOffset = _dragOffset
        context.coordinator.onDismiss = onDismiss

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        scrollView.addGestureRecognizer(pan)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostedView?.rootView = content
        context.coordinator.dragOffset = _dragOffset
        context.coordinator.onDismiss = onDismiss
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var hostedView: UIHostingController<Content>?
        var dragOffset: Binding<CGSize>?
        var onDismiss: (() -> Void)?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostedView?.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let isZoomed = scrollView.zoomScale > 1.0
            scrollView.isScrollEnabled = isZoomed
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            let isZoomed = scale > 1.0
            scrollView.isScrollEnabled = isZoomed
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            if scrollView.zoomScale > 1.0 {
                scrollView.setZoomScale(1.0, animated: true)
                scrollView.isScrollEnabled = false
            } else {
                let point = gesture.location(in: scrollView)
                let zoomRect = CGRect(x: point.x, y: point.y, width: 0, height: 0)
                scrollView.zoom(to: zoomRect, animated: true)
                scrollView.isScrollEnabled = true
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView, scrollView.zoomScale == 1.0 else { return }
            let translation = gesture.translation(in: scrollView)
            
            switch gesture.state {
            case .changed:
                if translation.y > 0 {
                    dragOffset?.wrappedValue = CGSize(width: translation.x, height: translation.y)
                }
            case .ended, .cancelled:
                if translation.y > 100 {
                    withAnimation(.easeOut(duration: 0.25)) {
                        dragOffset?.wrappedValue = CGSize(width: 0, height: UIScreen.main.bounds.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self.onDismiss?()
                    }
                } else {
                    withAnimation(.spring()) {
                        dragOffset?.wrappedValue = .zero
                    }
                }
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let scrollView = pan.view as? UIScrollView else { return true }
            
            if scrollView.zoomScale == 1.0 {
                let velocity = pan.velocity(in: scrollView)
                return velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
            }
            return false
        }
    }
}

func resolvePostAndAttachments(for media: Attachment, in parentPost: Post) -> (Post, [Attachment]) {
    let mainMediaList = parentPost.attachments.filter {
        switch $0 {
        case .remoteImage(_, _, _, _, _, _, _), .image(_), .remoteVideo(_, _, _, _, _, _, _, _, _, _, _), .video(_, _), .gif(_, _): return true
        default: return false
        }
    }
    if mainMediaList.contains(where: { $0.id == media.id }) {
        return (parentPost, mainMediaList)
    }
    
    for repost in parentPost.copyHistory {
        let repostMediaList = repost.attachments.filter {
            switch $0 {
            case .remoteImage(_, _, _, _, _, _, _), .image(_), .remoteVideo(_, _, _, _, _, _, _, _, _, _, _), .video(_, _), .gif(_, _): return true
            default: return false
            }
        }
        if repostMediaList.contains(where: { $0.id == media.id }) {
            return (repost, repostMediaList)
        }
    }
    
    return (parentPost, mainMediaList)
}

final class MediaCommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var newCommentText = ""
    @Published var totalCount = 0
    @Published var error: String?
    @Published var replyToComment: Comment?
    @Published var editingComment: Comment?
    
    let mediaType: String
    let ownerID: Int
    let mediaID: Int
    
    private let service: CommentsServiceProtocol
    private let pageSize = 20
    private var currentOffset = 0
    private(set) var hasMore = true
    
    var canSend: Bool {
        !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var replyPlaceholder: String {
        if editingComment != nil {
            return "Редактировать комментарий"
        }
        if let reply = replyToComment {
            return "Ответить \(reply.author.displayName)"
        }
        return "Написать комментарий"
    }
    
    init(mediaType: String, ownerID: Int, mediaID: Int, service: CommentsServiceProtocol = CommentsService.shared) {
        self.mediaType = mediaType
        self.ownerID = ownerID
        self.mediaID = mediaID
        self.service = service
    }
    
    func load() {
        isLoading = true
        error = nil
        currentOffset = 0
        
        service.fetchMediaComments(type: mediaType, ownerID: ownerID, mediaID: mediaID, offset: 0, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    self?.comments = response.comments
                    self?.totalCount = response.count
                    self?.currentOffset = response.comments.count
                    self?.hasMore = response.comments.count < response.count
                case .failure(let error):
                    self?.error = error.localizedDescription
                }
            }
        }
    }
    
    func loadMore() {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        
        service.fetchMediaComments(type: mediaType, ownerID: ownerID, mediaID: mediaID, offset: currentOffset, count: pageSize) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMore = false
                switch result {
                case .success(let response):
                    self?.comments.append(contentsOf: response.comments)
                    self?.currentOffset += response.comments.count
                    self?.hasMore = (self?.currentOffset ?? 0) < response.count
                case .failure:
                    break
                }
            }
        }
    }
    
    func sendComment() {
        var text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        if let edit = editingComment {
            newCommentText = ""
            editingComment = nil
            editComment(edit, newText: text)
            return
        }
        
        if let reply = replyToComment {
            text = "[id\(reply.fromId)|\(reply.author.displayName)], \(text)"
        }
        
        newCommentText = ""
        replyToComment = nil
        
        service.createMediaComment(type: mediaType, ownerID: ownerID, mediaID: mediaID, text: text) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let comment) = result {
                    self?.comments.append(comment)
                    self?.totalCount += 1
                }
            }
        }
    }
    
    func editComment(_ comment: Comment, newText: String) {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        
        let updated = Comment(
            id: comment.id,
            postId: comment.postId,
            fromId: comment.fromId,
            ownerId: comment.ownerId,
            author: comment.author,
            text: newText,
            date: comment.date,
            likesCount: comment.likesCount,
            isLiked: comment.isLiked,
            attachments: comment.attachments
        )
        comments[index] = updated
        
        service.editComment(commentID: comment.id, ownerID: ownerID, text: newText) { result in
            DispatchQueue.main.async {
                if case .failure = result {
                    self.comments[index] = comment
                }
            }
        }
    }
    
    func deleteComment(_ comment: Comment) {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        
        comments.remove(at: index)
        totalCount -= 1
        
        service.deleteComment(commentID: comment.id, ownerID: ownerID) { result in
            DispatchQueue.main.async {
                if case .failure = result {
                    self.comments.insert(comment, at: index)
                    self.totalCount += 1
                }
            }
        }
    }
    
    func setReply(to comment: Comment) {
        editingComment = nil
        replyToComment = comment
    }
    
    func cancelReply() {
        replyToComment = nil
    }
    
    func setEditing(_ comment: Comment) {
        replyToComment = nil
        editingComment = comment
        newCommentText = comment.text
    }
    
    func cancelEditing() {
        editingComment = nil
        newCommentText = ""
    }
    
    func toggleLike(for comment: Comment) {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }

        let optimistic = optimisticComment(comment, isLiked: !comment.isLiked)
        comments[index] = optimistic

        service.toggleLike(commentID: comment.id, ownerID: comment.ownerId, isLiked: comment.isLiked) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self,
                      let idx = self.comments.firstIndex(where: { $0.id == comment.id }) else { return }
                switch result {
                case .success(let response):
                    self.comments[idx] = self.optimisticComment(comment, isLiked: response.isLiked, likesCount: response.likesCount)
                case .failure:
                    self.comments[idx] = comment
                }
            }
        }
    }

    private func optimisticComment(_ comment: Comment, isLiked: Bool, likesCount: Int? = nil) -> Comment {
        let count = likesCount ?? (isLiked ? comment.likesCount + 1 : max(0, comment.likesCount - 1))
        return Comment(
            id: comment.id,
            postId: comment.postId,
            fromId: comment.fromId,
            ownerId: comment.ownerId,
            author: comment.author,
            text: comment.text,
            date: comment.date,
            likesCount: count,
            isLiked: isLiked,
            attachments: comment.attachments
        )
    }
}

struct MediaCommentsView: View {
    @StateObject private var viewModel: MediaCommentsViewModel
    @Environment(\.dismiss) private var dismiss
    var onCommentPosted: (() -> Void)?
    
    @State private var selectedProfileUser: User?
    @State private var tappedMedia: Attachment?
    @State private var deletingComment: Comment?
    
    private var currentUID: Int { AuthService.shared.currentUser?.uid ?? 0 }
    
    init(mediaType: String, ownerID: Int, mediaID: Int, onCommentPosted: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: MediaCommentsViewModel(mediaType: mediaType, ownerID: ownerID, mediaID: mediaID))
        self.onCommentPosted = onCommentPosted
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                NavigationLink(
                    destination: Group {
                        if let user = selectedProfileUser {
                            ProfileView(user: user, selectedMedia: $tappedMedia, owningPost: .constant(nil))
                        }
                    },
                    isActive: Binding(
                        get: { selectedProfileUser != nil },
                        set: { if !$0 { selectedProfileUser = nil } }
                    )
                ) {
                    EmptyView()
                }
                .hidden()
                
                ScrollView {
                    VStack(spacing: 0) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                .padding(.vertical, 40)
                        } else if viewModel.comments.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("Комментариев пока нет")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("Будьте первым, кто оставит комментарий!")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 60)
                            .padding(.horizontal, 40)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.comments) { comment in
                                    CommentRow(
                                        comment: comment,
                                        onLike: { viewModel.toggleLike(for: comment) },
                                        onReply: { viewModel.setReply(to: comment) },
                                        onUserTap: { id in navigateToUser(id: id, from: comment) },
                                        onMediaTap: { tappedMedia = $0 },
                                        onEdit: { viewModel.setEditing($0) },
                                        onDelete: { deletingComment = $0 },
                                        isOwnComment: comment.fromId == currentUID,
                                        canDelete: comment.fromId == currentUID || viewModel.ownerID == currentUID
                                    )
                                    Divider()
                                        .padding(.leading, 70)
                                }
                                
                                if viewModel.hasMore {
                                    if viewModel.isLoadingMore {
                                        ProgressView()
                                            .padding(.vertical, 20)
                                    } else {
                                        Button(action: { viewModel.loadMore() }) {
                                            Text("Загрузить ещё")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.appAccent)
                                                .padding(.vertical, 16)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                if let edit = viewModel.editingComment {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundColor(.appAccent)
                        Text("Редактирование")
                            .font(.system(size: 13))
                            .foregroundColor(.appAccent)
                        Spacer()
                        Button(action: { viewModel.cancelEditing() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.appAccent.opacity(0.08))
                }
                
                if let reply = viewModel.replyToComment {
                    HStack {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.appAccent)
                        Text("Ответ \(reply.author.displayName)")
                            .font(.system(size: 13))
                            .foregroundColor(.appAccent)
                        Spacer()
                        Button(action: { viewModel.cancelReply() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.appAccent.opacity(0.08))
                }
                
                Divider()
                HStack(spacing: 12) {
                    TextField(viewModel.replyPlaceholder, text: $viewModel.newCommentText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(18)
                        .font(.system(size: 14))
                    
                    if viewModel.canSend {
                        Button(action: { viewModel.sendComment() }) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.appAccent)
                                .padding(8)
                                .background(Color.appAccent.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .navigationTitle("Комментарии (\(viewModel.totalCount))")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Закрыть") { dismiss() })
            .onAppear {
                viewModel.load()
            }
            .onChange(of: viewModel.totalCount) { _ in
                onCommentPosted?()
            }
            .confirmationDialog("Удалить комментарий?", isPresented: Binding(get: { deletingComment != nil }, set: { if !$0 { deletingComment = nil } }), titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    if let comment = deletingComment {
                        viewModel.deleteComment(comment)
                    }
                    deletingComment = nil
                }
                Button("Отмена", role: .cancel) {
                    deletingComment = nil
                }
            } message: {
                Text("Это действие нельзя отменить.")
            }
        }
    }
    
    private func navigateToUser(id: Int, from comment: Comment) {
        if id == comment.fromId {
            selectedProfileUser = comment.author
        } else {
            let name = comment.text.mentionName(for: id) ?? "id\(abs(id))"
            selectedProfileUser = User(
                uid: id,
                username: id > 0 ? "id\(id)" : "club\(abs(id))",
                displayName: name,
                isGroup: id < 0
            )
        }
    }
}

import WebKit

struct GIFView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let html = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    background-color: transparent;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    overflow: hidden;
                }
                img {
                    max-width: 100%;
                    max-height: 100%;
                    object-fit: cover;
                    border-radius: 12px;
                }
            </style>
        </head>
        <body>
            <img src="\(urlString)">
        </body>
        </html>
        """
        uiView.loadHTMLString(html, baseURL: nil)
    }
}

struct GIFAttachmentView: View {
    let title: String
    let url: String
    let onTap: () -> Void
    @State private var isDownloading = false

    var body: some View {
        ZStack {
            GIFView(urlString: url)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            
            if isDownloading {
                Color.black.opacity(0.3)
                    .cornerRadius(12)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

