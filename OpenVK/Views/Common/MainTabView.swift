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
    @State private var tabletSidebarVisible = false
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

    // The drawer owns its drag state, so a finger movement never forces
    // the active chat, media gallery or profile to re-evaluate its body.
    private var tabletNavigation: some View {
        GeometryReader { geometry in
            let sidebarWidth = min(290, max(240, geometry.size.width * 0.26))

            ZStack(alignment: .leading) {
                tabletContent
                    .frame(width: geometry.size.width, height: geometry.size.height)

                TabletSidebarDrawer(isVisible: $tabletSidebarVisible, sidebarWidth: sidebarWidth) {
                    tabletSidebar
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(.systemBackground))
            .clipped()
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
                    tabletSidebarVisible = false
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
                    Button {
                        tabletDestination = .profile
                        tabletSidebarVisible = false
                    } label: {
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
                            tabletSidebarVisible = false
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


private struct TabletSidebarDrawer<Sidebar: View>: View {
    @Binding var isVisible: Bool
    let sidebarWidth: CGFloat
    let sidebar: Sidebar

    @GestureState private var dragTranslation: CGFloat = 0

    init(isVisible: Binding<Bool>, sidebarWidth: CGFloat,
         @ViewBuilder sidebar: () -> Sidebar) {
        _isVisible = isVisible
        self.sidebarWidth = sidebarWidth
        self.sidebar = sidebar()
    }

    private var progress: CGFloat {
        let requested = (isVisible ? sidebarWidth : 0) + dragTranslation
        return min(1, max(0, requested / max(1, sidebarWidth)))
    }

    private var interactiveSwipe: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, transaction in
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height) * 1.25 else { return }
                if isVisible {
                    state = min(0, dx)
                } else if value.startLocation.x <= 32 {
                    state = max(0, dx)
                }
                transaction.disablesAnimations = true
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.25 else { return }
                let projected = value.predictedEndTranslation.width
                if isVisible {
                    if dx < -sidebarWidth * 0.32 || projected < -sidebarWidth * 0.55 {
                        withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.87)) {
                            isVisible = false
                        }
                    }
                } else if value.startLocation.x <= 32,
                          dx > sidebarWidth * 0.32 || (value.startLocation.x <= 32 && projected > sidebarWidth * 0.55) {
                    withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.87)) {
                        isVisible = true
                    }
                }
            }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.black
                    .opacity(0.24 * progress)
                    .contentShape(Rectangle())
                    .allowsHitTesting(progress > 0.001)
                    .onTapGesture {
                        withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.87)) {
                            isVisible = false
                        }
                    }
                    .simultaneousGesture(interactiveSwipe)

                sidebar
                    .frame(width: sidebarWidth, height: geometry.size.height)
                    .offset(x: (progress - 1) * sidebarWidth)
                    .shadow(color: .black.opacity(0.2 * progress), radius: 12, x: 4)
                    .allowsHitTesting(progress > 0.01)
                    .simultaneousGesture(interactiveSwipe)
                    .zIndex(1)

                if !isVisible {
                    // The narrow hit region captures edge swipes without
                    // intercepting scrolling or tapping in the main content.
                    Color.clear
                        .frame(width: 26, height: geometry.size.height)
                        .contentShape(Rectangle())
                        .gesture(interactiveSwipe)
                        .zIndex(2)

                    Button {
                        withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.87)) {
                            isVisible = true
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Показать боковое меню")
                    // Below the navigation bar: never obscures a Back button.
                    .padding(.top, 56)
                    .padding(.leading, 12)
                    .zIndex(3)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .animation(.interactiveSpring(response: 0.30, dampingFraction: 0.87),
                       value: isVisible)
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

    private let logoHeight: CGFloat = 12
    private let verticalPadding: CGFloat = 5

    private var topPadding: CGFloat {
        guard topInset >= 59 else { return 6 }
        let plateHeight = logoHeight + verticalPadding * 2
        return max(0, topInset - 30 - plateHeight / 2)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Image("logo_full")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: logoHeight)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, verticalPadding)
            .background(Color.black.opacity(0.88))
            .clipShape(Capsule())
            .padding(.top, topPadding)

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
