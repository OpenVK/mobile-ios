import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var auth: AuthService

    @State private var showLoginSheet = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Аккаунты")) {
                    if let currentUser = auth.currentUser {
                        let activeAccount = auth.accounts.first(where: { $0.user.username == currentUser.username })
                        HStack(spacing: 12) {
                            Avatar(user: currentUser, size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(currentUser.displayName)
                                        .font(.system(size: 15))
                                    
                                    if currentUser.isOfficial == true {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.appAccent)
                                    }
                                    SupporterBadgeView(screenName: currentUser.username)
                                }
                                if let instance = activeAccount?.instanceOption.displayName {
                                    Text(instance)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.appAccent)
                                .font(.system(size: 16))
                        }
                        .padding(.vertical, 2)
                        .contextMenu {
                            Button("Удалить", role: .destructive) {
                                auth.signOut()
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }

                    let otherAccounts = auth.accounts.filter { $0.user.username != auth.currentUser?.username }
                    ForEach(otherAccounts) { account in
                        Button(action: {
                            auth.switchToAccount(account)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Avatar(user: account.user, size: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(account.user.displayName)
                                            .font(.system(size: 15))
                                            .foregroundColor(.primary)
                                        
                                        if account.user.isOfficial == true {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.appAccent)
                                        }
                                        SupporterBadgeView(screenName: account.user.username)
                                    }
                                    Text(account.instanceOption.displayName)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(.vertical, 2)
                        .contextMenu {
                            Button("Войти") {
                                auth.switchToAccount(account)
                                presentationMode.wrappedValue.dismiss()
                            }
                            Button("Удалить", role: .destructive) {
                                withAnimation {
                                    auth.removeAccount(byUsername: account.user.username)
                                }
                            }
                        }
                    }

                    Button(action: {
                        showLoginSheet = true
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.appAccent)
                            }
                            Text("Добавить аккаунт")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.appAccent)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section(header: Text("Настройки")) {
                    NavigationLink(destination: FeedSettingsView()) {
                        SettingsRow(icon: "list.bullet.rectangle", title: "Лента", iconColor: .appAccent)
                    }

                    NavigationLink(destination: DevicesSettingsView()) {
                        SettingsRow(icon: "iphone.badge.play", title: "Устройства", iconColor: .green)
                    }

                    NavigationLink(destination: AccountSettingsView()) {
                        SettingsRow(icon: "person.crop.circle", title: "Аккаунт", iconColor: .orange)
                    }

                    NavigationLink(destination: NotificationsSettingsView()) {
                        SettingsRow(icon: "bell.badge", title: "Уведомления и звуки", iconColor: .red)
                    }

                    NavigationLink(destination: PrivacySettingsView()) {
                        SettingsRow(icon: "hand.raised.fill", title: "Конфиденциальность", iconColor: .gray)
                    }

                    NavigationLink(destination: DataAndMemorySettingsView()) {
                        SettingsRow(icon: "internaldrive", title: "Данные и память", iconColor: .appAccent)
                    }

                    NavigationLink(destination: AppearanceSettingsView()) {
                        SettingsRow(icon: "paintbrush", title: "Внешний вид", iconColor: .purple)
                    }

                    NavigationLink(destination: PowerSavingSettingsView()) {
                        SettingsRow(icon: "battery.100.bolt", title: "Энергосбережение", iconColor: .yellow)
                    }

                    NavigationLink(destination: LanguageSettingsView()) {
                        SettingsRow(icon: "globe", title: "Язык", iconColor: .cyan)
                    }
                }

                Section() {
                    NavigationLink(destination: AboutAppView()) {
                        SettingsRow(icon: "info.circle", title: "О приложении", iconColor: .gray)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Готово") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLoginSheet) {
                LoginView(onSuccess: {
                    showLoginSheet = false
                }, onCancel: {
                    showLoginSheet = false
                })
                .environmentObject(auth)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct DevicesSettingsView: View {
    @State private var showTerminateAlert = false

    var body: some View {
        List {
            Section(header: Text("Это устройство")) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.green)
                            .frame(width: 28, height: 28)
                        Image(systemName: "iphone")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                    }
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("iOS Device")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(AppConfig.appName) \(AppConfig.versionString)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("Неизвестно") // todo сделать определение устройства
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section(header: Text("Сеансы")) {
                Button(action: {
                    showTerminateAlert = true
                }) {
                    Text("Завершить все сессии")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Устройства")
        .customBackButton(title: "Настройки")
        .alert(isPresented: $showTerminateAlert) {
            Alert(
                title: Text("В разработке"),
                message: Text("Функция завершения всех сессий находится в разработке и будет доступна в следующих версиях."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct AccountSettingsView: View {
    @State private var showInDevelopmentAlert = false

    var body: some View {
        List {
            Section(header: Text("Личные данные")) {
                Button(action: {
                    showInDevelopmentAlert = true
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.appAccent)
                                .frame(width: 28, height: 28)
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Почта")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }

                Button(action: {
                    showInDevelopmentAlert = true
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.appAccent)
                                .frame(width: 28, height: 28)
                            Image(systemName: "link")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Адрес страницы")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }

            Section {
                Button(action: {
                    showInDevelopmentAlert = true
                }) {
                    Text("Удалить страницу")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Аккаунт")
        .customBackButton(title: "Настройки")
        .alert(isPresented: $showInDevelopmentAlert) {
            Alert(
                title: Text("В разработке"),
                message: Text("Данная функция находится в разработке."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct FeedSettingsView: View {
    @State private var itemsPerPage = "10"
    @State private var startFromPage = "1"
    @State private var showIgnored = false
    @State private var showForeignWall = false

    var body: some View {
        List {
            Section {
                NavigationLink(destination: IgnoredSourcesView()) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.gray)
                                .frame(width: 28, height: 28)
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Игнорируемые источники")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }

            Section {
                Button(action: {
                    presentTextFieldAlert(
                        title: "Записей на странице",
                        message: "Укажите количество записей для отображения на одной странице:",
                        placeholder: "10",
                        initialText: itemsPerPage,
                        keyboardType: .numberPad
                    ) { newValue in
                        itemsPerPage = newValue
                    }
                }) {
                    HStack {
                        Text("Записей на странице")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(itemsPerPage)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    presentTextFieldAlert(
                        title: "Начинавать со страницы",
                        message: "Укажите номер страницы для начала загрузки:",
                        placeholder: "1",
                        initialText: startFromPage,
                        keyboardType: .numberPad
                    ) { newValue in
                        startFromPage = newValue
                    }
                }) {
                    HStack {
                        Text("Начинавать со страницы")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(startFromPage)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle("Показывать игнорируемые источники", isOn: $showIgnored)
                Toggle("Показывать посты на чужих стенах", isOn: $showForeignWall)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Лента")
        .customBackButton(title: "Настройки")
    }
}

struct NotificationsSettingsView: View {
    @State private var showNotifications = true
    @State private var userMsg = true
    @State private var userFriend = true
    @State private var userOther = true
    @State private var appSound = true
    @State private var appVibro = true
    @State private var appText = true
    @AppStorage("badge_msg") private var badgeMsg = true
    @AppStorage("badge_notify") private var badgeNotify = true
    @AppStorage("badge_friend") private var badgeFriend = true
    @State private var showResetAlert = false

    var body: some View {
        List {
            Section(header: Text("Показывать уведомления (в разработке!)")) {
                Toggle(isOn: $showNotifications) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.green)
                                .frame(width: 28, height: 28)
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Всех аккаунтов")
                    }
                }
            }

            Section(header: Text("Уведомления (в разработке!)")) {
                Toggle(isOn: $userMsg) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.appAccent)
                                .frame(width: 28, height: 28)
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Сообщения")
                    }
                }
                Toggle(isOn: $userFriend) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.green)
                                .frame(width: 28, height: 28)
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Заявки в друзья")
                    }
                }
                Toggle(isOn: $userOther) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.gray)
                                .frame(width: 28, height: 28)
                            Image(systemName: "ellipsis.bubble.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Прочие уведомления")
                    }
                }
            }

            Section(header: Text("Уведомления в приложении (в разработке!)")) {
                Toggle("Звук", isOn: $appSound)
                Toggle("Вибрация", isOn: $appVibro)
                Toggle("Показывать текст", isOn: $appText)
            }

            Section(header: Text("Счетчик на иконке")) {
                Toggle(isOn: $badgeMsg) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.appAccent)
                                .frame(width: 28, height: 28)
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Сообщения")
                    }
                }
                Toggle(isOn: $badgeNotify) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red)
                                .frame(width: 28, height: 28)
                            Image(systemName: "bell.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Уведомления")
                    }
                }
                Toggle(isOn: $badgeFriend) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.green)
                                .frame(width: 28, height: 28)
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Заявки в друзья")
                    }
                }
            }

            Section {
                Button(action: {
                    showResetAlert = true
                }) {
                    Text("Сбросить настройки уведомлений")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Уведомления и звуки")
        .customBackButton(title: "Настройки")
        .alert(isPresented: $showResetAlert) {
            Alert(
                title: Text("Сброс настроек"),
                message: Text("Все настройки уведомлений будут сброшены к значениям по умолчанию."),
                primaryButton: .destructive(Text("Сбросить")) {
                    showNotifications = true
                    userMsg = true
                    userFriend = true
                    userOther = true
                    appSound = true
                    appVibro = true
                    appText = true
                    badgeMsg = true
                    badgeNotify = true
                    badgeFriend = true
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
    }
}

struct PrivacySettingsView: View {
    @State private var selectionWeb = "Всем желающим"
    @State private var selectionInfo = "Всем желающим"
    @State private var selectionGroups = "Всем желающим"
    @State private var selectionPhotos = "Всем желающим"
    @State private var selectionVideos = "Всем желающим"
    @State private var selectionAudio = "Всем желающим"
    @State private var selectionNotes = "Всем желающим"
    @State private var selectionFriends = "Всем желающим"
    @State private var selectionFriendReq = "Все желающие"
    @State private var selectionWallPost = "Все желающие"
    @State private var selectionMsg = "Все желающие"
    @State private var selectionProfile = "Открытый"

    let options1 = ["Всем желающим", "Пользователям OpenVK"]
    let options2 = ["Всем желающим", "Пользователям OpenVK", "Друзьям", "Только мне"]
    let options3 = ["Все желающие", "Никто"]
    let options4 = ["Все желающие", "Друзья", "Только я"]
    let options5 = ["Все желающие", "Друзья", "Никто"]
    let options6 = ["Открытый", "Закрытый"]

    private var biometricInfo: (title: String, icon: String) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return ("Код-пароль", "lock.fill")
        }
        
        switch context.biometryType {
        case .faceID:
            return ("Код-пароль и Face ID", "faceid")
        case .touchID:
            return ("Код-пароль и Touch ID", "touchid")
        default:
            return ("Код-пароль", "lock.fill")
        }
    }

    var body: some View {
        List {
            Section {
                NavigationLink(destination: PlaceholderSettingsView(title: "Чёрный список", backButtonTitle: "Конфиденциальность")) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red)
                                .frame(width: 28, height: 28)
                            Image(systemName: "slash.circle")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Чёрный список")
                    }
                }
                
                let bio = biometricInfo
                NavigationLink(destination: PlaceholderSettingsView(title: bio.title, backButtonTitle: "Конфиденциальность")) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.appAccent)
                                .frame(width: 28, height: 28)
                            Image(systemName: bio.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text(bio.title)
                    }
                }
            }

            Section(header: Text("Конфиденциальность (в разработке!)")) {
                Picker("Кому в интернете видно мою страницу", selection: $selectionWeb) {
                    ForEach(options1, id: \.self) { Text($0) }
                }
                Picker("Кому видно основную информацию страницы", selection: $selectionInfo) {
                    ForEach(options2, id: \.self) { Text($0) }
                }
                Picker("Кому видно мои группы и встречи", selection: $selectionGroups) {
                    ForEach(options2, id: \.self) { Text($0) }
                }
                Picker("Кому видно мои фотографии", selection: $selectionPhotos) {
                    ForEach(options2, id: \.self) { Text($0) }
                }
                Picker("Кому видно мои видеозаписи", selection: $selectionVideos) {
                    ForEach(options2, id: \.self) { Text($0) }
                }
                Picker("Кому видно мои аудиозаписи", selection: $selectionAudio) {
                    ForEach(options2, id: \.self) { Text($0) }
                }
                Picker("Кому видно мои заметки", selection: $selectionNotes) {
                    ForEach(options2, id: \.self) { Text($0) }
                }
                Picker("Кому видно моих друзей", selection: $selectionFriends) {
                    ForEach(options2, id: \.self) { Text($0) }
                }
                Picker("Кто может называть меня другом", selection: $selectionFriendReq) {
                    ForEach(options3, id: \.self) { Text($0) }
                }
                Picker("Кто может писать у меня на стене", selection: $selectionWallPost) {
                    ForEach(options4, id: \.self) { Text($0) }
                }
                Picker("Кто может писать мне сообщения", selection: $selectionMsg) {
                    ForEach(options5, id: \.self) { Text($0) }
                }
                Picker("Тип профиля", selection: $selectionProfile) {
                    ForEach(options6, id: \.self) { Text($0) }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Конфиденциальность")
        .customBackButton(title: "Настройки")
    }
}

struct DataAndMemorySettingsView: View {
    @State private var cacheSize: String = "..."
    @State private var showClearCacheAlert = false
    @State private var cacheCleared = false

    var body: some View {
        List {
            Section(header: Text("Память")) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.green)
                            .frame(width: 28, height: 28)
                        Image(systemName: "internaldrive")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                    }
                    Text("Использование памяти")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(cacheSize)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    showClearCacheAlert = true
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red)
                                .frame(width: 28, height: 28)
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Очистить кэш")
                            .foregroundColor(cacheCleared ? .secondary : .primary)
                        Spacer()
                        if cacheCleared {
                            Image(systemName: "checkmark")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                    }
                }
                .disabled(cacheCleared)
            }

            Section(footer: Text("Кэш хранит ответы API и изображения для ускорения работы приложения. Данные обновляются автоматически каждые 5 минут.")) {
                EmptyView()
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Данные и память")
        .customBackButton(title: "Настройки")
        .onAppear {
            refreshCacheSize()
        }
        .alert(isPresented: $showClearCacheAlert) {
            Alert(
                title: Text("Очистка кэша"),
                message: Text("Вы уверены, что хотите очистить кэш? Это освободит \(cacheSize)."),
                primaryButton: .destructive(Text("Очистить")) {
                    CacheService.shared.clearAll()
                    withAnimation {
                        cacheCleared = true
                        cacheSize = "0 байт"
                    }
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
    }

    private func refreshCacheSize() {
        DispatchQueue.global(qos: .utility).async {
            let size = CacheService.shared.totalCacheSizeString()
            DispatchQueue.main.async {
                self.cacheSize = size
            }
        }
    }
}

struct PlaceholderSettingsView: View {
    let title: String
    var backButtonTitle: String = "Назад"

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Раздел «\(title)» находится на стадии разработки и будет доступен в следующих версиях.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .navigationTitle(title)
        .customBackButton(title: backButtonTitle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
            }
            
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct IgnoredSourcesView: View {
    @State private var ignoredUsers: [User] = [
        User(username: "user", displayName: "User", lastSeen: "был вчера в 13:56")
    ]
    @State private var showAddSourceAlert = false

    var body: some View {
        List {
            Section {
                Button(action: {
                    showAddSourceAlert = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.appAccent)
                            .font(.system(size: 18))
                        Text("Добавить источник...")
                            .foregroundColor(.appAccent)
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }

            if !ignoredUsers.isEmpty {
                Section(header: Text("Игнорируемые пользователи")) {
                    ForEach(ignoredUsers, id: \.username) { user in
                        HStack(spacing: 12) {
                            Avatar(user: user, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(user.displayName)
                                        .font(.system(size: 15, weight: .medium))
                                    
                                    if user.isOfficial == true {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.appAccent)
                                    }
                                    SupporterBadgeView(screenName: user.username)
                                }
                                Text("@\(user.username)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Удалить") {
                                withAnimation {
                                    ignoredUsers.removeAll { $0.username == user.username }
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                Text("Список игнорируемых источников пуст.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Игнорируемые источники")
        .customBackButton(title: "Лента")
        .alert(isPresented: $showAddSourceAlert) {
            Alert(
                title: Text("В разработке"),
                message: Text("Функция добавления новых источников находится в разработке."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

extension View {
    func presentTextFieldAlert(
        title: String,
        message: String? = nil,
        placeholder: String = "",
        initialText: String = "",
        keyboardType: UIKeyboardType = .default,
        onConfirm: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = placeholder
            textField.text = initialText
            textField.keyboardType = keyboardType
        }

        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        let confirmAction = UIAlertAction(title: "Сохранить", style: .default) { _ in
            if let text = alert.textFields?.first?.text {
                onConfirm(text)
            }
        }

        alert.addAction(cancelAction)
        alert.addAction(confirmAction)

        showAlertController(alert)
    }

    private func showAlertController(_ alert: UIAlertController) {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(alert, animated: true)
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("openvk.theme_selection") private var themeSelection = 0 // 0: Системная, 1: Светлая, 2: Тёмная
    @AppStorage("openvk.accent_color") private var accentColorSelection = "Синий"
    @AppStorage("openvk.font_scale") private var fontSizeSelection = 1.0 // Slider scale from 0.8 to 1.4

    let themes = ["Системная", "Светлая", "Тёмная"]
    let accentColors = ["Синий", "Голубой", "Розовый", "Фиолетовый", "Зеленый", "Оранжевый", "Красный"]

    var body: some View {
        List {
            Section(header: Text("Цветовая тема")) {
                Picker("Тема оформления", selection: $themeSelection) {
                    ForEach(0..<themes.count, id: \.self) { index in
                        Text(themes[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.vertical, 2)

                Picker("Акцентный цвет", selection: $accentColorSelection) {
                    ForEach(accentColors, id: \.self) { color in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(colorCircle(for: color))
                                .frame(width: 14, height: 14)
                            Text(color)
                        }
                        .tag(color)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Внешний вид")
        .customBackButton(title: "Настройки")
    }

    private func colorCircle(for colorName: String) -> Color {
        appAccentColor(for: colorName)
    }
}

struct PowerSavingSettingsView: View {
    @State private var powerSavingEnabled = false
    @State private var autoplayAnimations = true
    @State private var preloadMedia = true
    @State private var backgroundRefresh = true

    var body: some View {
        List {
            Section(
                header: Text("Основное (в разработке!)"),
                footer: Text("Режим энергосбережения продлевает время работы аккумулятора, ограничивая фоновую активность и визуальные эффекты интерфейса.")
            ) {
                Toggle(isOn: $powerSavingEnabled) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.yellow)
                                .frame(width: 28, height: 28)
                            Image(systemName: "battery.100.bolt")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                        }
                        Text("Энергосбережение")
                    }
                }
                .onChange(of: powerSavingEnabled) { enabled in
                    if enabled {
                        autoplayAnimations = false
                        preloadMedia = false
                        backgroundRefresh = false
                    } else {
                        autoplayAnimations = true
                        preloadMedia = true
                        backgroundRefresh = true
                    }
                }
            }

            Section(header: Text("Ограничения (в разработке!)")) {
                Toggle("Автозапуск анимаций", isOn: $autoplayAnimations)
                    .disabled(powerSavingEnabled)
                Toggle("Предзагрузка медиа", isOn: $preloadMedia)
                    .disabled(powerSavingEnabled)
                Toggle("Фоновое обновление", isOn: $backgroundRefresh)
                    .disabled(powerSavingEnabled)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Энергосбережение")
        .customBackButton(title: "Настройки")
    }
}

struct LanguageSettingsView: View {
    var body: some View {
        UnderDevelopmentView(section: "Язык интерфейса")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Язык интерфейса")
            .customBackButton(title: "Настройки")
    }
}

struct AboutAppView: View {
    @State private var rotationX: CGFloat = 0
    @State private var rotationY: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                rotatableLogo

                VStack(spacing: 6) {
                    Text("OpenVK for iOS")
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text(versionText)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            List {
                Section(header: Text("Дисклеймер")) {
                    Text(appDisclaimer)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }

                Section {
                    authorRow(name: "Ника Фалалеева", handle: "nikanikoo", role: "Разработчик приложения")
                    authorRow(name: "Владимир Баринов", handle: "Veselcraft", role: "CEO OpenVK")

                    NavigationLink(destination: SupportersListView()) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.appAccent.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.appAccent)
                            }
                            Text("Другие")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section(header: Text("Ссылки")) {
                    Link(destination: URL(string: "https://openvk.org")!) {
                        linkRow(icon: "safari", title: "Сайт OpenVK", subtitle: "openvk.org")
                    }
                    Link(destination: URL(string: "https://github.com/OpenVK/openvk-ios")!) {
                        linkRow(icon: "doc.text", title: "GitHub", subtitle: "github.com/OpenVK/openvk-ios")
                    }
                    Link(destination: URL(string: "https://dalink.to/inkslate_official")!) {
                        linkRow(icon: "link", title: "Поддержать проект", subtitle: nil)
                    }
                }

                Section(header: Text("Лицензия")) {
                    HStack {
                        Label("Лицензия", systemImage: "scroll")
                        Spacer()
                        Text("AGPL-3.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("О приложении")
        .customBackButton(title: "Настройки")
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Версия \(version) (\(build))"
    }

    private var rotatableLogo: some View {
        Image("logo")
            .resizable()
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
            .rotation3DEffect(.degrees(Double(rotationY)), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .rotation3DEffect(.degrees(Double(-rotationX)), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        rotationY = value.translation.width / 3.2
                        rotationX = value.translation.height / 4.5
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                            rotationX = 0
                            rotationY = 0
                        }
                    }
            )
    }

    private func linkRow(icon: String, title: String, subtitle: String?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.appAccent.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appAccent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func authorRow(name: String, handle: String, role: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text(handle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Text(role)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
