//
//  AlbumsListView.swift
//  OpenVK for iOS
//
//  Экран альбомов.
//

import SwiftUI

struct AlbumsListView: View {

    @StateObject private var viewModel: AlbumsListViewModel
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    init(ownerID: Int, selectedMedia: Binding<Attachment?>, owningPost: Binding<Post?>) {
        _viewModel = StateObject(wrappedValue: AlbumsListViewModel(ownerID: ownerID))
        _selectedMedia = selectedMedia
        _owningPost = owningPost
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
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
            } else if viewModel.albums.isEmpty {
                VStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    Text("Нет альбомов")
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(viewModel.albums) { album in
                            NavigationLink(destination: AlbumDetailView(album: album, selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                                albumCell(album)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Фотографии")
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

    private func albumCell(_ album: PhotoAlbum) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fill)
                .overlay(
                    Group {
                        if let url = album.coverURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure, .empty:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(album.coverColor)
                                        Image(systemName: album.coverSystemName)
                                            .font(.system(size: 30))
                                            .foregroundColor(Color.white.opacity(0.92))
                                    }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(album.coverColor)
                                Image(systemName: album.coverSystemName)
                                    .font(.system(size: 30))
                                    .foregroundColor(Color.white.opacity(0.92))
                            }
                        }
                    }
                )
                .cornerRadius(12)
                .clipped()

            Text(album.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text("\(album.count) фото")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}
