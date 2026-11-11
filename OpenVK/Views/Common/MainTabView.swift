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
    @State private var tabletDestination: TabletSidebarDestination = .feed
    @State private var tabletSidebarVisible = true
    @State private var showNewPost = false
    @State private var topInset: CGFloat = 0
    @State private var bottomInset: CGFloat = 0
    @State private var selectedMedia: Attachment? = nil
    @State private var owningPost: Post? = nil
    @StateObject private var connectionStatus = ConnectionStatusService.shared

    var body: some View {
        ZStack {
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    tabletNavigation
                } else {
                    phoneNavigation
                }
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
                .onAppear {
                    pauseAudioIfNeeded(for: media)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .zIndex(100)
            }

            if selectedMedia == nil {
                GlobalAudioPlayerOverlay(bottomInset: bottomInset)
                    .zIndex(200)
            }
        }
        .onAppear {
            auth.fetchCounters()
            connectionStatus.start()
        }
    }


    private var phoneNavigation: some View {
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

                MessagesView(
                    selectedMedia: $selectedMedia,
                    owningPost: $owningPost
                )
                .tabItem {
                    Label(AppTab.messages.label, systemImage: selectedTab == .messages ? AppTab.messages.iconFilled : AppTab.messages.icon)
                }
                .tag(AppTab.messages)

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
            .overlay(alignment: .top) {
                if UIDevice.current.userInterfaceIdiom == .phone && topInset >= 44 { // Только iPhone с челкой (>=44) или островком (>=59)
                    BrandingPlate(topInset: topInset)
                        .ignoresSafeArea(.all, edges: .top)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let issue = connectionStatus.issue {
                    ConnectionStatusButton(issue: issue) {
                        connectionStatus.refresh()
                    }
                    .padding(.top, topInset + 48)
                    .padding(.trailing, 12)
                    .zIndex(10)
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            topInset = geometry.safeAreaInsets.top
                            bottomInset = geometry.safeAreaInsets.bottom
                        }
                        .onChange(of: geometry.safeAreaInsets.top) { newValue in
                            topInset = newValue
                        }
                        .onChange(of: geometry.safeAreaInsets.bottom) { newValue in
                            bottomInset = newValue
                        }
                }
            )
            .sheet(isPresented: $showNewPost) {
                NewPostView(isPresented: $showNewPost)
                    .accentColor(Color.appAccent)
                    .tint(Color.appAccent)
            }
    }

    private var tabletNavigation: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if tabletSidebarVisible {
                    tabletSidebar
                        .frame(width: min(270, max(230, geometry.size.width * 0.23)))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    Divider()
                }

                tabletContent
                    .id(tabletDestination)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topLeading) {
                        if !tabletSidebarVisible {
                            Button {
                                withAnimation(.easeInOut(duration: 0.26)) {
                                    tabletSidebarVisible = true
                                }
                            } label: {
                                Image(systemName: "sidebar.left")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.appAccent)
                                    .frame(width: 42, height: 42)
                                    .background(.regularMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 12)
                            .padding(.top, 8)
                            .accessibilityLabel("Показать боковое меню")
                        }
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(.systemBackground))
            .onAppear { bottomInset = geometry.safeAreaInsets.bottom }
            .onChange(of: geometry.safeAreaInsets.bottom) { bottomInset = $0 }
        }
        .sheet(isPresented: $showNewPost) {
            NewPostView(isPresented: $showNewPost)
                .accentColor(Color.appAccent)
                .tint(Color.appAccent)
        }
        .overlay(alignment: .topTrailing) {
            if let issue = connectionStatus.issue {
                ConnectionStatusButton(issue: issue) { connectionStatus.refresh() }
                    .padding(.top, 6)
                    .padding(.trailing, 10)
            }
        }
    }

    private var tabletSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("OpenVK")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.26)) {
                        tabletSidebarVisible = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 18))
                }
                .accessibilityLabel("Скрыть боковое меню")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    Button { tabletDestination = .profile } label: {
                        HStack(spacing: 12) {
                            Avatar(user: auth.currentUser ?? .current, size: 42)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(auth.currentUser?.displayName ?? "Мой профиль")
                                    .font(.system(size: 15, weight: .semibold))
                                    .lineLimit(1)
                                Text("Мой профиль")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(tabletDestination == .profile ? Color.appAccent.opacity(0.13) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.vertical, 9)

                    ForEach(TabletSidebarDestination.menuItems) { item in
                        Button {
                            tabletDestination = item
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 18))
                                    .frame(width: 26)
                                Text(item.rawValue)
                                    .font(.system(size: 15, weight: tabletDestination == item ? .semibold : .regular))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(tabletDestination == item ? Color.appAccent : Color.primary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 11)
                            .background(tabletDestination == item ? Color.appAccent.opacity(0.13) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 110)
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private var tabletContent: some View {
        switch tabletDestination {
        case .feed:
            FeedView(showNewPost: $showNewPost, selectedMedia: $selectedMedia, owningPost: $owningPost)
        case .profile:
            NavigationView {
                ProfileView(user: auth.currentUser ?? .current,
                            selectedMedia: $selectedMedia, owningPost: $owningPost)
            }
            .navigationViewStyle(.stack)
        case .feedback:
            NavigationView {
                NotificationsView(selectedMedia: $selectedMedia, owningPost: $owningPost)
            }
            .navigationViewStyle(.stack)
        case .messages:
            MessagesView(selectedMedia: $selectedMedia, owningPost: $owningPost)
        case .friends:
            NavigationView {
                FriendsListView(ownerID: auth.currentUser?.uid ?? 0,
                                selectedMedia: $selectedMedia, owningPost: $owningPost)
            }
            .navigationViewStyle(.stack)
        case .groups:
            NavigationView {
                GroupsListView(ownerID: auth.currentUser?.uid ?? 0,
                               selectedMedia: $selectedMedia, owningPost: $owningPost)
            }
            .navigationViewStyle(.stack)
        case .photos:
            NavigationView {
                AlbumsListView(ownerID: auth.currentUser?.uid ?? 0,
                               selectedMedia: $selectedMedia, owningPost: $owningPost)
            }
            .navigationViewStyle(.stack)
        case .videos:
            NavigationView {
                VideosListView(ownerID: auth.currentUser?.uid ?? 0,
                               selectedMedia: $selectedMedia, owningPost: $owningPost)
            }
            .navigationViewStyle(.stack)
        case .audio:
            NavigationView { AudioListView().environmentObject(auth) }
                .navigationViewStyle(.stack)
        case .stickers:
            NavigationView { StickerStoreView() }
                .navigationViewStyle(.stack)
        case .documents:
            NavigationView { DocumentsListView() }
                .navigationViewStyle(.stack)
        case .settings:
            SettingsView().environmentObject(auth)
        case .notes, .apps:
            NavigationView {
                VStack(spacing: 12) {
                    Image(systemName: tabletDestination.icon).font(.largeTitle)
                    Text("Раздел находится в разработке")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(tabletDestination.rawValue)
            }
            .navigationViewStyle(.stack)
        case .balance:
            NavigationView {
                VStack(spacing: 10) {
                    Text("Баланс").font(.title2.weight(.bold))
                    Text("\(auth.balanceVotes) голосов").font(.title3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Баланс")
                .onAppear { auth.fetchBalance() }
            }
            .navigationViewStyle(.stack)
        }
    }

    private func pauseAudioIfNeeded(for media: Attachment) {
        switch media {
        case .video(_, _),
             .remoteVideo(_, _, _, _, _, _, _, _, _, _, _):
            AudioPlayerService.shared.pause()
        default:
            break
        }
    }
}

private struct ConnectionStatusButton: View {
    let issue: ConnectionStatusService.Issue
    let retry: () -> Void

    @State private var showDetails = false

    var body: some View {
        Button {
            showDetails = true
        } label: {
            Image(systemName: issue == .noInternet ? "wifi.slash" : "server.rack")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.red)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(issue.title)
        .sheet(isPresented: $showDetails) {
            NavigationView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: issue == .noInternet ? "wifi.slash" : "server.rack")
                        .font(.system(size: 38))
                        .foregroundColor(.red)

                    Text(issue.title)
                        .font(.title2.weight(.bold))

                    Text(issue.details)
                        .font(.body)
                        .foregroundColor(.secondary)

                    Button(action: retry) {
                        Label("Проверить снова", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Spacer()
                }
                .padding(24)
                .navigationTitle("Подключение")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть") { showDetails = false }
                    }
                }
            }
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


private enum TabletSidebarDestination: String, CaseIterable, Identifiable {
    case profile = "Мой профиль"
    case feed = "Новости"
    case feedback = "Ответы"
    case messages = "Сообщения"
    case friends = "Друзья"
    case groups = "Группы"
    case photos = "Фотографии"
    case videos = "Видеозаписи"
    case audio = "Аудиозаписи"
    case notes = "Заметки"
    case apps = "Приложения"
    case stickers = "Стикеры"
    case documents = "Документы"
    case balance = "Баланс"
    case settings = "Настройки"

    var id: String { rawValue }
    static var menuItems: [Self] { allCases.filter { $0 != .profile } }

    var icon: String {
        switch self {
        case .profile: return "person.crop.circle"
        case .feed: return "house"
        case .feedback: return "bell"
        case .messages: return "bubble.left.and.bubble.right"
        case .friends: return "person.2"
        case .groups: return "person.3"
        case .photos: return "photo.on.rectangle"
        case .videos: return "play.rectangle"
        case .audio: return "music.note"
        case .notes: return "note.text"
        case .apps: return "square.grid.3x3"
        case .stickers: return "face.smiling"
        case .documents: return "doc.text"
        case .balance: return "rublesign.circle"
        case .settings: return "gearshape"
        }
    }
}
