//
//  ProfileWallSection.swift
//  OpenVK for iOS
//

import SwiftUI

struct ProfileWallSection: View {

    let posts: [Post]
    let isLoadingMore: Bool
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?
    var onLike: (Post) -> Void = { _ in }
    var onCommentTap: (Post) -> Void = { _ in }
    var onRepost: (Post, Int) -> Void = { _, _ in }
    var onLoadMore: () -> Void = {}

    var body: some View {
        Group {
            HStack {
                Text(L10n.Profile.postsHeader)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(.secondaryLabel))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            SectionSeparator(opacity: 1.0)

            ForEach(posts) { post in
                PostCard(
                    post: post,
                    onLike: { onLike(post) },
                    onCommentTap: { clickedPost in
                        onCommentTap(clickedPost)
                    },
                    onRepost: { repostsCount in
                        onRepost(post, repostsCount)
                    },
                    selectedMedia: $selectedMedia,
                    owningPost: $owningPost
                )
                .onAppear {
                    if post.vkID == posts.last?.vkID {
                        onLoadMore()
                    }
                }
                SectionSeparator()
            }
            
            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 16)
                    Spacer()
                }
            }
        }
    }
}
