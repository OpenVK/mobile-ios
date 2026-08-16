//
//  FeedView.swift
//  OpenVK for iOS
//
//  Экран ленты.
//

import SwiftUI

struct FeedView: View {

    @Binding var showNewPost: Bool
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    @StateObject private var viewModel = FeedViewModel()
    @EnvironmentObject var auth: AuthService

    init(showNewPost: Binding<Bool>, selectedMedia: Binding<Attachment?> = .constant(nil), owningPost: Binding<Post?> = .constant(nil)) {
        self._showNewPost = showNewPost
        self._selectedMedia = selectedMedia
        self._owningPost = owningPost
    }

    var body: some View {
        NavigationView {
            mainFeedContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
                .background(
                    detailNavigationLink
                )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { viewModel.load() }
    }

    @ViewBuilder
    private var mainFeedContent: some View {
        List {
            if viewModel.isLoading && viewModel.filteredPosts.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.vertical, 80)
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.filteredPosts) { post in
                    VStack(spacing: 0) {
                        PostCard(
                            post: post,
                            onLike: {
                                viewModel.toggleLike(for: post)
                            },
                            onCommentTap: { clickedPost in
                                viewModel.selectedPost = clickedPost
                                viewModel.showDetail = true
                            },
                            onRepost: { repostsCount in
                                viewModel.updateRepostsCount(for: post, count: repostsCount)
                            },
                            selectedMedia: $selectedMedia,
                            owningPost: $owningPost
                        )
                        .onAppear {
                            if post.id == viewModel.filteredPosts.last?.id {
                                viewModel.loadNextPage()
                            }
                        }
                        
                        SectionSeparator()
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 16)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(PlainListStyle())
        .environment(\.defaultMinListHeaderHeight, 0)
        .refreshable {
            auth.fetchCounters()
            await viewModel.refreshAsync(clearPosts: false)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Menu {
                ForEach(FeedType.allCases) { type in
                    Button(action: {
                        withAnimation {
                            viewModel.feedType = type
                        }
                    }) {
                        HStack {
                            Text(type.rawValue)
                            if viewModel.feedType == type {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.feedType.rawValue)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }

        ToolbarItem(placement: .navigationBarLeading) {
            NavigationLink(destination: NotificationsView(selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                Image(systemName: "bell")
                    .font(.system(size: 17))
                    .foregroundColor(.appAccent)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Group {
                            if auth.notificationsCount > 0 {
                                Text("\(auth.notificationsCount)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 0.5)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        },
                        alignment: .topTrailing
                    )
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showNewPost = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17))
                    .foregroundColor(.appAccent)
            }
        }
    }

    private var detailNavigationLink: some View {
        NavigationLink(
            destination: Group {
                if let post = viewModel.selectedPost {
                    PostDetailView(
                        post: post,
                        selectedMedia: $selectedMedia,
                        owningPost: $owningPost
                    )
                }
            },
            isActive: $viewModel.showDetail
        ) {
            EmptyView()
        }
        .hidden()
    }
}

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView(showNewPost: .constant(false))
            .environmentObject(AuthService.shared)
    }
}
