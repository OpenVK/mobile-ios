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
        GeometryReader { geometry in
            ScrollView {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    if #available(iOS 16.0, *) {
                        // Switching AnyLayout preserves the content hierarchy
                        // and media views instead of destroying both columns
                        // on every rotation.
                        adaptiveTabletProfile(availableWidth: geometry.size.width,
                                              landscape: geometry.size.width > geometry.size.height)
                    } else if geometry.size.width > geometry.size.height {
                        tabletProfileContent(availableWidth: geometry.size.width)
                    } else {
                        compactProfileContent
                            .frame(maxWidth: 600)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    compactProfileContent
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
        .onAppear { viewModel.loadIfNeeded() }
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


    @available(iOS 16.0, *)
    private func adaptiveTabletProfile(availableWidth: CGFloat, landscape: Bool) -> some View {
        let horizontalSpace = max(1, availableWidth - 32)
        let portraitWidth = min(600, horizontalSpace)
        let columnWidth = min(330, max(270, horizontalSpace * 0.30))
        let wallWidth = min(720, max(1, horizontalSpace - columnWidth - 18))
        let layout = AnyLayout(landscape
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 18))
            : AnyLayout(VStackLayout(spacing: 0)))

        return layout {
            VStack(spacing: 0) {
                ProfileHeaderView(
                    user: viewModel.user,
                    avatarRefreshToken: viewModel.avatarRefreshToken
                )
                if viewModel.user.accessStatus == .active {
                    if !landscape { SectionSpacer() }
                    ProfileInfoSection(user: viewModel.user, onTapDetails: {
                        showDetailedInfo = true
                    })
                }
            }
            .frame(width: landscape ? columnWidth : portraitWidth)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 0) {
                switch viewModel.user.accessStatus {
                case .deleted, .banned, .blacklistedByThem, .blacklistedByMe, .privateProfile:
                    ProfileStatusBanner(status: viewModel.user.accessStatus, user: viewModel.user)
                case .active:
                    if viewModel.photoCount > 0 {
                        if !landscape { SectionSpacer() }
                        ProfilePhotosSection(
                            photos: viewModel.photos,
                            photoCount: viewModel.photoCount,
                            user: viewModel.user,
                            selectedMedia: $selectedMedia,
                            owningPost: $owningPost
                        )
                    }
                    SectionSpacer()
                    profileWallContent
                }
            }
            .frame(width: landscape ? wallWidth : portraitWidth)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: landscape ? 1090 : 600)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var compactProfileContent: some View {
        LazyVStack(spacing: 0) {
            ProfileHeaderView(
                user: viewModel.user,
                avatarRefreshToken: viewModel.avatarRefreshToken
            )
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

    @ViewBuilder
    private func tabletProfileContent(availableWidth: CGFloat) -> some View {
        let columnWidth = min(330, max(270, availableWidth * 0.30))
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 0) {
                ProfileHeaderView(
                    user: viewModel.user,
                    avatarRefreshToken: viewModel.avatarRefreshToken
                )
                if viewModel.user.accessStatus == .active {
                    ProfileInfoSection(user: viewModel.user, onTapDetails: {
                        showDetailedInfo = true
                    })
                }
            }
            .frame(width: columnWidth)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 0) {
                switch viewModel.user.accessStatus {
                case .deleted, .banned, .blacklistedByThem, .blacklistedByMe, .privateProfile:
                    ProfileStatusBanner(status: viewModel.user.accessStatus, user: viewModel.user)
                case .active:
                    if viewModel.photoCount > 0 {
                        ProfilePhotosSection(
                            photos: viewModel.photos,
                            photoCount: viewModel.photoCount,
                            user: viewModel.user,
                            selectedMedia: $selectedMedia,
                            owningPost: $owningPost
                        )
                        SectionSpacer()
                    }
                    profileWallContent
                }
            }
            .frame(maxWidth: 720)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: 1090, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var profileWallContent: some View {
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

        profileWallContent
    }
}
