//
//  VideosListView.swift
//  OpenVK for iOS
//
//  Экран видеозаписей.
//

import SwiftUI

struct VideosListView: View {

    @StateObject private var viewModel: VideosListViewModel
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    init(ownerID: Int, selectedMedia: Binding<Attachment?>, owningPost: Binding<Post?>) {
        _viewModel = StateObject(wrappedValue: VideosListViewModel(ownerID: ownerID))
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
            } else if viewModel.videos.isEmpty {
                VStack {
                    Image(systemName: "video.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    Text("Видеозаписи не найдены")
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(viewModel.videos) { video in
                            Button(action: {
                                let videoAttachment = Attachment.remoteVideo(
                                    title: video.title,
                                    duration: video.duration,
                                    imageURL: video.imageURL?.absoluteString ?? "",
                                    videoURL: video.playerURL?.absoluteString,
                                    id: video.vkID,
                                    ownerID: video.ownerID,
                                    files: video.files,
                                    likesCount: video.likesCount,
                                    commentsCount: video.commentsCount,
                                    repostsCount: video.repostsCount,
                                    isLiked: video.isLiked
                                )
                                
                                let attachments = viewModel.videos.map { v -> Attachment in
                                    Attachment.remoteVideo(
                                        title: v.title,
                                        duration: v.duration,
                                        imageURL: v.imageURL?.absoluteString ?? "",
                                        videoURL: v.playerURL?.absoluteString,
                                        id: v.vkID,
                                        ownerID: v.ownerID,
                                        files: v.files,
                                        likesCount: v.likesCount,
                                        commentsCount: v.commentsCount,
                                        repostsCount: v.repostsCount,
                                        isLiked: v.isLiked
                                    )
                                }
                                
                                let dummyPost = Post(
                                    author: User(username: "video_list", displayName: "Видеозаписи"),
                                    timeAgo: "",
                                    text: "",
                                    attachments: attachments
                                )
                                
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    self.owningPost = dummyPost
                                    self.selectedMedia = videoAttachment
                                }
                            }) {
                                videoCell(video)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .navigationTitle("Видеозаписи")
        .navigationBarTitleDisplayMode(.large)
        .customBackButton(title: "Назад")
        .refreshable {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                viewModel.load {
                    continuation.resume()
                }
            }
        }
        .onAppear {
            viewModel.load()
        }
    }

    private func videoCell(_ video: Video) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fill)
            .overlay(
                ZStack {
                    if let url = video.imageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                Rectangle()
                                    .fill(video.color)
                                    .overlay(
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color.white.opacity(0.8))
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(video.color)
                        Image(systemName: "video.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.white.opacity(0.8))
                    }
                    
                    // Play icon overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.white.opacity(0.92))

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(video.duration)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                                .padding(4)
                        }
                    }
                }
            )
            .clipped()
    }
}
