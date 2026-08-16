//
//  AlbumDetailView.swift
//  OpenVK for iOS
//
//  Экран альбома
//

import SwiftUI

struct AlbumDetailView: View {

    @StateObject private var viewModel: AlbumDetailViewModel
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    init(album: PhotoAlbum, selectedMedia: Binding<Attachment?>, owningPost: Binding<Post?>) {
        _viewModel = StateObject(wrappedValue: AlbumDetailViewModel(album: album))
        _selectedMedia = selectedMedia
        _owningPost = owningPost
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)

            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("Повторить") {
                        viewModel.load()
                    }
                    .buttonStyle(.bordered)
                }
            } else if viewModel.photos.isEmpty {
                VStack {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    Text("В альбоме нет фотографий")
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(viewModel.photos) { photo in
                            Button(action: {
                                let photoAttachment: Attachment
                                if let url = photo.imageURL {
                                    photoAttachment = .remoteImage(
                                        url: url.absoluteString,
                                        id: photo.vkID,
                                        ownerID: photo.ownerID,
                                        likesCount: photo.likesCount,
                                        commentsCount: photo.commentsCount,
                                        repostsCount: photo.repostsCount,
                                        isLiked: photo.isLiked
                                    )
                                } else {
                                    photoAttachment = .image(systemName: photo.systemName)
                                }
                                
                                let attachments = viewModel.photos.map { p -> Attachment in
                                    if let url = p.imageURL {
                                        return .remoteImage(
                                            url: url.absoluteString,
                                            id: p.vkID,
                                            ownerID: p.ownerID,
                                            likesCount: p.likesCount,
                                            commentsCount: p.commentsCount,
                                            repostsCount: p.repostsCount,
                                            isLiked: p.isLiked
                                        )
                                    } else {
                                        return .image(systemName: p.systemName)
                                    }
                                }
                                
                                let dummyPost = Post(
                                    author: User(username: "album", displayName: viewModel.album.title),
                                    timeAgo: "",
                                    text: "",
                                    attachments: attachments
                                )
                                
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    self.owningPost = dummyPost
                                    self.selectedMedia = photoAttachment
                                }
                            }) {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fill)
                                    .overlay(
                                        Group {
                                            if let url = photo.imageURL {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                    case .failure, .empty:
                                                        Rectangle()
                                                            .fill(photo.color)
                                                            .overlay(
                                                                Image(systemName: photo.systemName)
                                                                    .font(.system(size: 22))
                                                                    .foregroundColor(Color.white.opacity(0.9))
                                                            )
                                                    @unknown default:
                                                        EmptyView()
                                                    }
                                                }
                                            } else {
                                                Rectangle()
                                                    .fill(photo.color)
                                                    .overlay(
                                                        Image(systemName: photo.systemName)
                                                            .font(.system(size: 22))
                                                            .foregroundColor(Color.white.opacity(0.9))
                                                    )
                                            }
                                        }
                                    )
                                    .clipped()
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.album.title)
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton(title: "Назад")
        .onAppear {
            viewModel.load()
        }
    }
}
