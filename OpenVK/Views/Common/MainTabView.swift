//
//  MainTabView.swift
//  OpenVK for iOS
//
//  Главное окно с табами.
//

import SwiftUI

struct MainTabView: View {

    @EnvironmentObject var auth: AuthService
    @State private var selectedTab: AppTab = .feed
    @State private var showNewPost = false
    @State private var topInset: CGFloat = 0
    @State private var selectedMedia: Attachment? = nil
    @State private var owningPost: Post? = nil

    var body: some View {
        ZStack {
            ZStack(alignment: .top) {
                TabView(selection: $selectedTab) {
                    FeedView(
                        showNewPost: $showNewPost,
                        selectedMedia: $selectedMedia,
                        owningPost: $owningPost
                    )
                    .tabItem {
                        Label(AppTab.feed.label, systemImage: selectedTab == .feed ? AppTab.feed.iconFilled : AppTab.feed.icon)
                    }
                    .tag(AppTab.feed)

                    SearchView(
                        selectedMedia: $selectedMedia,
                        owningPost: $owningPost
                    )
                    .tabItem {
                        Label(AppTab.search.label, systemImage: selectedTab == .search ? AppTab.search.iconFilled : AppTab.search.icon)
                    }
                    .tag(AppTab.search)

                    MessagesView()
                    .tabItem {
                        Label(AppTab.messages.label, systemImage: selectedTab == .messages ? AppTab.messages.iconFilled : AppTab.messages.icon)
                    }
                    .tag(AppTab.messages)
                    .badge(auth.messagesCount > 0 ? "\(auth.messagesCount)" : nil)

                    MoreView(
                        selectedMedia: $selectedMedia,
                        owningPost: $owningPost
                    )
                    .tabItem {
                        Label(AppTab.more.label, systemImage: selectedTab == .more ? AppTab.more.iconFilled : AppTab.more.icon)
                    }
                    .tag(AppTab.more)
                    .badge(auth.friendsCount > 0 ? "\(auth.friendsCount)" : nil)
                }
                
                if UIDevice.current.userInterfaceIdiom == .phone && topInset >= 44 { // Только iPhone с челкой (>=44) или островком (>=59)
                    BrandingPlate(topInset: topInset)
                        .ignoresSafeArea(.all, edges: .top)
                        .allowsHitTesting(false)
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            topInset = geometry.safeAreaInsets.top
                        }
                        .onChange(of: geometry.safeAreaInsets.top) { newValue in
                            topInset = newValue
                        }
                }
            )
            .sheet(isPresented: $showNewPost) {
                NewPostView(isPresented: $showNewPost)
                    .accentColor(Color.appAccent)
                    .tint(Color.appAccent)
            }
            
            if let media = selectedMedia, let post = owningPost {
                let (postToUse, attachmentsToUse) = resolvePostAndAttachments(for: media, in: post)
                let index = attachmentsToUse.firstIndex(where: { $0.id == media.id }) ?? 0
                
                MediaFullScreenViewer(
                    post: postToUse,
                    attachments: attachmentsToUse,
                    initialSelectedIndex: index,
                    onLikeToggle: {
                    },
                    onCommentTap: {},
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            self.selectedMedia = nil
                            self.owningPost = nil
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .zIndex(100)
            }
        }
        .onAppear {
            auth.fetchCounters()
        }
    }
}

private struct BrandingPlate: View {
    let topInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Image("logo_full")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 12)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.88))
            .clipShape(Capsule())
            .padding(.top, topInset >= 59 ? 14 : 6)

            Spacer()
        }
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MainTabView().preferredColorScheme(.light)
            MainTabView().preferredColorScheme(.dark)
        }
        .environmentObject(AuthService.shared)
    }
}
