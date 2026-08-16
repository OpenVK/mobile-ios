//
//  ProfilePhotosSection.swift
//  OpenVK for iOS
//

import SwiftUI

struct ProfilePhotosSection: View {

    let photos: [Photo]
    let photoCount: Int
    let user: User
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    init(
        photos: [Photo],
        photoCount: Int,
        user: User,
        selectedMedia: Binding<Attachment?> = .constant(nil),
        owningPost: Binding<Post?> = .constant(nil)
    ) {
        self.photos = photos
        self.photoCount = photoCount
        self.user = user
        self._selectedMedia = selectedMedia
        self._owningPost = owningPost
    }

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(destination: AlbumsListView(ownerID: user.uid ?? 0, selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                HStack {
                    Text(L10n.Profile.photosHeader)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(.secondaryLabel))
                    Spacer()
                    Text("\(photoCount)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.secondaryLabel))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.top, 14)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photos.prefix(6)) { photo in
                    Button(action: {
                        openPhotoViewer(for: photo)
                    }) {
                        if let url = photo.imageURL {
                            RemoteImage(url: url, placeholder: Rectangle().fill(Color(.secondarySystemBackground)))
                                .aspectRatio(1, contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(photo.color.opacity(0.15))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Image(systemName: photo.systemName)
                                        .font(.system(size: 22))
                                        .foregroundColor(photo.color)
                                )
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.bottom, 14)
        }
        .background(Color(.systemBackground))
    }

    private func openPhotoViewer(for selectedPhoto: Photo) {
        let photoAttachment: Attachment
        if let url = selectedPhoto.imageURL {
            photoAttachment = .remoteImage(
                url: url.absoluteString,
                id: selectedPhoto.vkID,
                ownerID: selectedPhoto.ownerID,
                likesCount: selectedPhoto.likesCount,
                commentsCount: selectedPhoto.commentsCount,
                repostsCount: selectedPhoto.repostsCount,
                isLiked: selectedPhoto.isLiked
            )
        } else {
            photoAttachment = .image(systemName: selectedPhoto.systemName)
        }

        let attachments = photos.map { p -> Attachment in
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
            author: user,
            timeAgo: "",
            text: "",
            attachments: attachments
        )

        withAnimation(.easeInOut(duration: 0.25)) {
            self.owningPost = dummyPost
            self.selectedMedia = photoAttachment
        }
    }
}
