//
//  ProfileView.swift
//  OpenVK for iOS
//
//  Экран профиля.
//

import SwiftUI

struct ProfileView: View {

    @StateObject private var viewModel: ProfileViewModel
    @State private var showNewPost = false
    @State private var showDetailedInfo = false
    @State private var selectedPost: Post? = nil
    @State private var showDetail = false
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    init(user: User = .current, selectedMedia: Binding<Attachment?> = .constant(nil), owningPost: Binding<Post?> = .constant(nil)) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(user: user))
        self._selectedMedia = selectedMedia
        self._owningPost = owningPost
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {

                ProfileHeaderView(user: viewModel.user)

                switch viewModel.user.accessStatus {
                case .deleted, .banned, .blacklistedByThem, .blacklistedByMe, .privateProfile:
                    SectionSpacer()
                    ProfileStatusBanner(status: viewModel.user.accessStatus, user: viewModel.user)

                case .active:
                    SectionSpacer()
                    profileContent
                }
            }
        }
        .navigationBarTitle("@\(viewModel.user.username)")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton(title: "Назад")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.user.accessStatus == .active && viewModel.user.canCreatePost {
                    Button(action: { showNewPost = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17))
                            .foregroundColor(.appAccent)
                    }
                }
            }
        }
        .sheet(isPresented: $showNewPost) {
            NewPostView(
                isPresented: $showNewPost,
                ownerID: viewModel.user.uid,
                targetUser: viewModel.user,
                onPostCreated: { newPost in
                    viewModel.insertPost(newPost)
                }
            )
            .accentColor(Color.appAccent)
            .tint(Color.appAccent)
        }
        .sheet(isPresented: $showDetailedInfo) {
            DetailedProfileInfoView(user: viewModel.user)
                .accentColor(Color.appAccent)
                .tint(Color.appAccent)
        }
        .onAppear { viewModel.load() }
        .background(
            NavigationLink(
                destination: Group {
                    if let post = selectedPost {
                        PostDetailView(
                            post: post,
                            selectedMedia: $selectedMedia,
                            owningPost: $owningPost
                        )
                    }
                },
                isActive: $showDetail
            ) {
                EmptyView()
            }
            .hidden()
        )
    }

    @ViewBuilder
    private var profileContent: some View {
        ProfileInfoSection(user: viewModel.user, onTapDetails: {
            showDetailedInfo = true
        })

        if viewModel.photoCount > 0 {
            SectionSpacer()
            ProfilePhotosSection(
                photos: viewModel.photos,
                photoCount: viewModel.photoCount,
                user: viewModel.user,
                selectedMedia: $selectedMedia,
                owningPost: $owningPost
            )
        }

        SectionSpacer()

        ProfileWallSection(
            posts: viewModel.wall,
            isLoadingMore: viewModel.isLoadingMoreWall,
            selectedMedia: $selectedMedia,
            owningPost: $owningPost,
            onLike: { post in
                viewModel.like(post: post)
            },
            onCommentTap: { post in
                self.selectedPost = post
                self.showDetail = true
            },
            onRepost: { post, repostsCount in
                viewModel.updateRepostsCount(for: post, count: repostsCount)
            },
            onLoadMore: {
                viewModel.loadMoreWall()
            }
        )
    }
}
