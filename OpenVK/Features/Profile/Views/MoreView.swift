//
//  MoreView.swift
//  OpenVK for iOS
//
//  Раздел «Прочее».
//

import SwiftUI

struct MoreView: View {

    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    init(selectedMedia: Binding<Attachment?> = .constant(nil), owningPost: Binding<Post?> = .constant(nil)) {
        self._selectedMedia = selectedMedia
        self._owningPost = owningPost
    }

    enum MoreAlert: Identifiable {
        case unavailable

        var id: Int { hashValue }
    }

    enum MoreSheet: Identifiable {
        case settings
        case addAccount

        var id: Int { hashValue }
    }

    @EnvironmentObject var auth: AuthService
    @StateObject private var birthdaysVM = BirthdaysViewModel()
    @State private var activeAlert: MoreAlert?
    @State private var activeSheet: MoreSheet?

    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: ProfileView(user: auth.currentUser ?? .current, selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                        HStack(spacing: 12) {
                            Avatar(user: auth.currentUser ?? .current, size: 48)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text(auth.currentUser?.displayName ?? "User")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    if (auth.currentUser ?? .current).isOfficial == true {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 15))
                                            .foregroundColor(.appAccent)
                                    }
                                    SupporterBadgeView(screenName: (auth.currentUser ?? .current).username)
                                }
                                Text("Перейти в профиль")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section {
                    NavigationLink(destination: FriendsListView(ownerID: auth.currentUser?.uid ?? 0, selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                        HStack {
                            Label("Друзья", systemImage: "person.2.fill")
                                .labelStyle(SettingsLabelStyle(iconColor: .green))
                            if auth.friendsCount > 0 {
                                Spacer()
                                Text("\(auth.friendsCount)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    NavigationLink(destination: GroupsListView(ownerID: auth.currentUser?.uid ?? 0, selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                        Label("Группы", systemImage: "person.3.fill")
                            .labelStyle(SettingsLabelStyle(iconColor: .orange))
                    }

                    NavigationLink(destination: AlbumsListView(ownerID: auth.currentUser?.uid ?? 0, selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                        Label("Фотографии", systemImage: "photo.on.rectangle.fill")
                            .labelStyle(SettingsLabelStyle(iconColor: .cyan))
                    }

                    NavigationLink(destination: VideosListView(ownerID: auth.currentUser?.uid ?? 0, selectedMedia: $selectedMedia, owningPost: $owningPost)) {
                        Label("Видеозаписи", systemImage: "play.rectangle.fill")
                            .labelStyle(SettingsLabelStyle(iconColor: .red))
                    }

                    Button(action: { activeAlert = .unavailable }) {
                        Label("Аудиозаписи", systemImage: "music.note")
                            .labelStyle(SettingsLabelStyle(iconColor: .appAccent))
                    }
                    .foregroundColor(.primary)

                    Button(action: { activeAlert = .unavailable }) {
                        Label("Заметки", systemImage: "note.text")
                            .labelStyle(SettingsLabelStyle(iconColor: .yellow))
                    }
                    .foregroundColor(.primary)

                    Button(action: { activeAlert = .unavailable }) {
                        Label("Приложения", systemImage: "square.grid.3x3.fill")
                            .labelStyle(SettingsLabelStyle(iconColor: .purple))
                    }
                    .foregroundColor(.primary)

                    NavigationLink(destination: DocumentsListView()) {
                        Label("Документы", systemImage: "doc.text.fill")
                            .labelStyle(SettingsLabelStyle(iconColor: .gray))
                    }
                    .foregroundColor(.primary)

                    HStack {
                        Button(action: { activeAlert = .unavailable }) {
                            Label("Баланс", systemImage: "rublesign.circle.fill")
                                .labelStyle(SettingsLabelStyle(iconColor: .orange))
                        }
                        .foregroundColor(.primary)
                        Spacer()
                        if !auth.isBalanceLoading || auth.balanceVotes > 0 {
                            Text(votesString(auth.balanceVotes))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if !birthdaysVM.isLoading && !birthdaysVM.nearbyBirthdays.isEmpty {
                    Section(header: Text("Дни рождения")) {
                        ForEach(birthdaysVM.nearbyBirthdays) { birthday in
                            HStack(spacing: 12) {
                                Avatar(user: birthday.user, size: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(birthday.user.displayName)
                                        .font(.system(size: 15))
                                    Text(birthday.relativeText)
                                        .font(.system(size: 13))
                                        .foregroundColor(birthday.isToday ? .appAccent : .secondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onAppear {
                birthdaysVM.loadIfNeeded()
                auth.fetchBalance()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Menu {
                        ForEach(auth.accounts) { account in
                            let isActive = (account.token == auth.token || account.user.username == auth.currentUser?.username)
                            AccountMenuItem(
                                account: account,
                                isActive: isActive,
                                onSelect: {
                                    if !isActive {
                                        withAnimation {
                                            auth.switchToAccount(account)
                                        }
                                    }
                                }
                            )
                        }

                        Button(action: {
                            activeSheet = .addAccount
                        }) {
                            Label("Добавить аккаунт", systemImage: "plus")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(auth.currentUser?.displayName ?? "User")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if (auth.currentUser ?? .current).isOfficial == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.appAccent)
                            }
                            SupporterBadgeView(screenName: (auth.currentUser ?? .current).username)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        activeSheet = .settings
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17))
                            .foregroundColor(.appAccent)
                    }
                }
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .unavailable:
                    return Alert(
                        title: Text("В разработке"),
                        message: Text("Раздел находится в разработке и будет доступен в следующих версиях."),
                        dismissButton: .cancel(Text("OK"))
                    )
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView()
                        .environmentObject(auth)
                        .accentColor(Color.appAccent)
                        .tint(Color.appAccent)
                case .addAccount:
                    LoginView(onSuccess: {
                        activeSheet = nil
                    }, onCancel: {
                        activeSheet = nil
                    })
                    .environmentObject(auth)
                    .accentColor(Color.appAccent)
                    .tint(Color.appAccent)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func votesString(_ count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100
        
        if remainder100 >= 11 && remainder100 <= 19 {
            return "\(count) голосов"
        }
        
        switch remainder10 {
        case 1:
            return "\(count) голос"
        case 2, 3, 4:
            return "\(count) голоса"
        default:
            return "\(count) голосов"
        }
    }

}

private struct AccountMenuItem: View {
    let account: AuthAccount
    let isActive: Bool
    let onSelect: () -> Void

    @State private var avatarImage: UIImage? = nil

    var body: some View {
        Button(action: onSelect) {
            Label(
                title: {
                    if isActive {
                        Text("\(account.user.displayName)  ✓")
                    } else {
                        Text(account.user.displayName)
                    }
                },
                icon: {
                    if let img = avatarImage {
                        Image(uiImage: img)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
            )
        }
        .onAppear {
            loadAvatar()
        }
    }

    private func loadAvatar() {
        guard let url = account.user.avatarURL else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let rawImage = UIImage(data: data) else { return }
            let circular = makeCircularImage(from: rawImage, size: 32)
            DispatchQueue.main.async {
                self.avatarImage = circular
            }
        }.resume()
    }

    private func makeCircularImage(from image: UIImage, size: CGFloat) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0.0)
        UIBezierPath(roundedRect: rect, cornerRadius: size / 2.0).addClip()
        image.draw(in: rect)
        let circularImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return (circularImage ?? image).withRenderingMode(.alwaysOriginal)
    }
}

struct SettingsLabelStyle: LabelStyle {
    let iconColor: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 28, height: 28)
                configuration.icon
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
            }
            configuration.title
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
    }
}

struct MoreView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MoreView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light")
            MoreView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
        .environmentObject(AuthService.shared)
    }
}
