//
//  ChatInfoView.swift
//  OpenVK for iOS
//

import SwiftUI
import AVKit
import PhotosUI

struct ChatInfoView: View {
    @Environment(\.dismiss) private var dismiss
    private enum ActiveAlert: Identifiable {
        case unavailable
        case archiveHelp
        case error(String)

        var id: String {
            switch self {
            case .unavailable: return "unavailable"
            case .archiveHelp: return "archiveHelp"
            case .error(let message): return "error:\(message)"
            }
        }
    }

    @StateObject private var model: ChatInfoViewModel
    @State private var showsAddMembers = false
    @State private var showsSettingsEditor = false
    @State private var confirmsClearHistory = false
    @State private var confirmsLeaveChat = false
    @State private var activeAlert: ActiveAlert?
    @State private var memberToExclude: ChatMember?
    @State private var preview: ChatMaterial?
    @State private var showsProfile = false
    @Binding private var selectedMedia: Attachment?
    @Binding private var owningPost: Post?

    init(conversation: Conversation, selectedMedia: Binding<Attachment?> = .constant(nil), owningPost: Binding<Post?> = .constant(nil)) {
        _selectedMedia = selectedMedia
        _owningPost = owningPost
        _model = StateObject(wrappedValue: ChatInfoViewModel(conversation: conversation))
    }

    var body: some View {
        List {
            header
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            sectionPicker
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            sectionContent(model.selectedSection)
        }
        .listStyle(.plain)
        .background {
            NavigationLink(
                destination: ProfileView(user: model.conversation.peer, selectedMedia: $selectedMedia, owningPost: $owningPost),
                isActive: $showsProfile
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .chatTabBarHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if model.canEdit {
                    Button("Изм.") { showsSettingsEditor = true }
                }
            }
        }
        .onAppear { model.load() }
        .onChange(of: model.shouldDismiss) { shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .onChange(of: model.selectedSection) { model.loadMaterials($0) }
        .onChange(of: model.errorMessage) { message in
            if let message { activeAlert = .error(message) }
        }
        .sheet(isPresented: $showsAddMembers) {
            ChatAddParticipantsView(model: model)
        }
        .sheet(isPresented: $showsSettingsEditor) {
            ChatSettingsEditorView(model: model)
        }
        .sheet(item: $preview) { item in
            ChatMaterialPreviewView(item: item)
        }
        .confirmationDialog(
            "Подтвердить действие",
            isPresented: Binding(
                get: { confirmsClearHistory || confirmsLeaveChat || memberToExclude != nil },
                set: { if !$0 {
                    confirmsClearHistory = false
                    confirmsLeaveChat = false
                    memberToExclude = nil
                } }
            ),
            titleVisibility: .visible
        ) {
            if confirmsClearHistory {
                Button("Очистить историю", role: .destructive) {
                    confirmsClearHistory = false
                    model.clearHistory()
                }
            } else if confirmsLeaveChat {
                Button("Выйти из беседы", role: .destructive) {
                    confirmsLeaveChat = false
                    model.leaveConversation()
                }
            } else if let memberToExclude {
                Button("Исключить \(memberToExclude.user.displayName)", role: .destructive) {
                    model.exclude(memberToExclude)
                    self.memberToExclude = nil
                }
            }
            Button("Отмена", role: .cancel) {
                confirmsClearHistory = false
                confirmsLeaveChat = false
                memberToExclude = nil
            }
        } message: {
            if confirmsClearHistory {
                Text("История будет удалена из вашего списка диалогов.")
            } else if confirmsLeaveChat {
                Text("Вы больше не будете участником беседы.")
            } else {
                Text("Участник потеряет доступ к беседе.")
            }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .unavailable:
                return Alert(
                    title: Text("В разработке"),
                    message: Text("Раздел находится в разработке и будет доступен в следующих версиях."),
                    dismissButton: .cancel(Text("ОК"))
                )
            case .archiveHelp:
                return Alert(
                    title: Text("Чат добавлен в архив"),
                    message: Text("Чтобы открыть архив, нажмите кнопку архива в верхней части списка сообщений. Вернуться можно кнопкой «Назад» или свайпом от левого края экрана."),
                    dismissButton: .default(Text("Понятно"))
                )
            case .error(let message):
                return Alert(
                    title: Text("Ошибка"),
                    message: Text(message),
                    dismissButton: .cancel(Text("ОК")) { model.errorMessage = nil }
                )
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Avatar(
                user: model.conversation.isChat
                    ? User(uid: model.conversation.id, username: "", displayName: model.title, avatarURL: model.photoURL)
                    : model.conversation.peer,
                size: 92,
                placeholderImageName: model.conversation.isChat ? "chat_default_100" : nil,
                isChat: model.conversation.isChat
            )
            .padding(.top, 12)

            HStack(spacing: 4) {
                Text(model.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if !model.conversation.isChat {
                    if model.conversation.peer.isOfficial == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.appAccent)
                            .accessibilityLabel("Подтверждённый аккаунт")
                    }
                    SupporterBadgeView(screenName: model.conversation.peer.username)
                }
            }

            if model.conversation.isChat {
                Text("\(model.memberCount) \(memberCountWord(model.memberCount))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !model.conversation.isGroup {
                Text(model.conversation.peer.isOnline ? "В сети" : (model.conversation.peer.lastSeen ?? "Не в сети"))
                    .font(.subheadline)
                    .foregroundStyle(model.conversation.peer.isOnline ? Color.appAccent : .secondary)
            }

            HStack(spacing: 0) {
                Button {
                    model.toggleMute()
                } label: {
                    actionLabel(title: "Звук", icon: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .accessibilityValue(model.isMuted ? "Выключен" : "Включён")

                if model.conversation.isChat {
                    Button {
                        activeAlert = .unavailable
                    } label: {
                        actionLabel(title: "Поиск", icon: "magnifyingglass")
                    }
                } else {
                    Button { showsProfile = true } label: {
                        actionLabel(title: "Профиль", icon: "person.crop.circle")
                    }
                }

                Menu {
                    Button {
                        model.markAllAsRead()
                    } label: {
                        Label("Пометить всё прочитанным", systemImage: "envelope.open")
                    }
                    Button {
                        model.toggleArchive()
                        if ChatArchiveStore.takePendingFirstArchiveTip() {
                            activeAlert = .archiveHelp
                        }
                    } label: {
                        Label(
                            ChatArchiveStore.contains(model.conversation.id)
                                ? "Вернуть из архива" : "В архив",
                            systemImage: "archivebox"
                        )
                    }
                    Button(role: .destructive) {
                        confirmsClearHistory = true
                    } label: {
                        Label("Очистить историю", systemImage: "bubble.left.and.bubble.right")
                    }
                    if model.conversation.isChat {
                        Button(role: .destructive) {
                            confirmsLeaveChat = true
                        } label: {
                            Label("Выйти из беседы", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } label: {
                    actionLabel(title: "Ещё", icon: "ellipsis")
                }
                .accessibilityLabel(model.conversation.isChat ? "Действия с беседой" : "Действия с перепиской")
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func actionLabel(title: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Color.appAccent)
                .frame(width: 54, height: 54)
                .background(Color(.tertiarySystemFill), in: Circle())
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.availableSections) { section in
                    Button {
                        model.selectedSection = section
                    } label: {
                        Text(section.title)
                            .font(.subheadline.weight(model.selectedSection == section ? .semibold : .regular))
                            .foregroundStyle(model.selectedSection == section ? Color.appAccent : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                model.selectedSection == section
                                    ? Color.appAccent.opacity(0.14)
                                    : Color(.secondarySystemGroupedBackground),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func sectionContent(_ section: ChatMaterialSection) -> some View {
        if section == .members {
            membersContent
        } else {
            materialsContent(section)
        }
    }

    private var membersContent: some View {
        Group {
            Button { showsAddMembers = true } label: {
                Label("Добавить участников", systemImage: "person.badge.plus")
            }
            .disabled(!model.canAddMembers)

            if model.isLoadingMembers && model.members.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(model.members) { member in
                    memberWithActions(member)
                }
            }
        }
    }

    @ViewBuilder
    private func memberWithActions(_ member: ChatMember) -> some View {
        if model.canAssign(member) || model.canExclude(member) {
            memberRow(member)
                .contextMenu {
                    if model.canAssign(member) {
                        Button {
                            model.setModerator(member, enabled: !member.isModerator)
                        } label: {
                            Label(
                                member.isModerator ? "Снять права модератора" : "Назначить модератором",
                                systemImage: member.isModerator ? "person.crop.circle.badge.minus" : "star"
                            )
                        }
                    }
                    if model.canExclude(member) {
                        Button(role: .destructive) {
                            memberToExclude = member
                        } label: {
                            Label("Исключить", systemImage: "person.crop.circle.badge.xmark")
                        }
                    }
                }
        } else {
            memberRow(member)
        }
    }

    private func memberRow(_ member: ChatMember) -> some View {
        NavigationLink(destination: ProfileView(user: member.user)) {
            HStack(spacing: 12) {
                Avatar(user: member.user, size: 42)
                Text(member.user.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let role = member.roleTitle {
                    Text(role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private func materialsContent(_ section: ChatMaterialSection) -> some View {
        let state = model.materials[section] ?? ChatInfoViewModel.MaterialState()
        if state.isLoading && state.items.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
        } else if let error = state.error, state.items.isEmpty {
            VStack(spacing: 10) {
                Text(error).foregroundStyle(.secondary)
                Button("Повторить") { model.loadMaterials(section) }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
        } else if state.hasLoaded && state.items.isEmpty {
            Text("Здесь пока нет материалов")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
        } else if section == .photos || section == .videos {
            ForEach(Array(stride(from: 0, to: state.items.count, by: 3)), id: \.self) { start in
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                    ForEach(Array(state.items[start..<min(start + 3, state.items.count)])) { item in
                        Button { preview = item } label: { materialTile(item, isVideo: section == .videos) }
                            .buttonStyle(.plain)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .onAppear {
                    if start + 3 >= state.items.count, let last = state.items.last {
                        model.loadMoreIfNeeded(section: section, item: last)
                    }
                }
            }
            if state.isLoading {
                ProgressView().frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        } else {
            ForEach(state.items) { item in
                materialRow(item, section: section)
                    .onAppear { model.loadMoreIfNeeded(section: section, item: item) }
            }
            if state.isLoading {
                ProgressView().frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
    }

    private func materialTile(_ item: ChatMaterial, isVideo: Bool) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                ZStack {
                    Color(.secondarySystemBackground)
                    AsyncImage(url: item.photoURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.clear
                    }
                    if isVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                    }
                }
            }
            .clipped()
            .accessibilityLabel(item.title)
    }

    private func materialRow(_ item: ChatMaterial, section: ChatMaterialSection) -> some View {
        let url = item.audioURL ?? item.documentURL ?? item.linkURL
        return Group {
            if let url {
                Link(destination: url) { materialRowLabel(item, section: section) }
            } else {
                materialRowLabel(item, section: section)
            }
        }
    }

    private func materialRowLabel(_ item: ChatMaterial, section: ChatMaterialSection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: section == .audio ? "music.note" : section == .documents ? "doc" : "link")
                .font(.system(size: 19))
                .foregroundStyle(Color.appAccent)
                .frame(width: 40, height: 40)
                .background(Color.appAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private func memberCountWord(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if (11...14).contains(lastTwo) { return "участников" }
        if last == 1 { return "участник" }
        if (2...4).contains(last) { return "участника" }
        return "участников"
    }
}

private struct ChatSettingsEditorView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var model: ChatInfoViewModel
    @State private var title: String
    @State private var confirmsInviteReset = false
    @State private var confirmsAvatarDelete = false
    @State private var showsAddMembers = false
    @State private var showsPermissionsEditor = false
    @State private var memberToExclude: ChatMember?

    init(model: ChatInfoViewModel) {
        self.model = model
        _title = State(initialValue: model.title)
    }

    var body: some View {
        NavigationView {
            Form {
                chatDetailsSection
                participantsSection
                inviteSection
            }
            .navigationTitle("Изменить беседу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        if title.trimmingCharacters(in: .whitespacesAndNewlines) == model.title {
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            model.updateTitle(title) { success in
                                if success { presentationMode.wrappedValue.dismiss() }
                            }
                        }
                    }
                    .disabled(
                        !model.canEditTitle ||
                        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        model.isWorking
                    )
                }
            }
            .sheet(isPresented: $showsAddMembers) {
                ChatAddParticipantsView(model: model)
            }
            .sheet(isPresented: $showsPermissionsEditor) {
                ChatPermissionsEditorView(model: model)
            }
            .confirmationDialog(
                "Подтвердить изменение",
                isPresented: Binding(
                    get: { memberToExclude != nil || confirmsAvatarDelete || confirmsInviteReset },
                    set: { if !$0 {
                        memberToExclude = nil
                        confirmsAvatarDelete = false
                        confirmsInviteReset = false
                    } }
                ),
                titleVisibility: .visible
            ) {
                if let memberToExclude {
                    Button("Исключить \(memberToExclude.user.displayName)", role: .destructive) {
                        model.exclude(memberToExclude)
                        self.memberToExclude = nil
                    }
                } else if confirmsAvatarDelete {
                    Button("Удалить фотографию", role: .destructive) {
                        confirmsAvatarDelete = false
                        model.removeAvatar()
                    }
                } else if confirmsInviteReset {
                    Button("Создать новую ссылку", role: .destructive) {
                        confirmsInviteReset = false
                        model.regenerateInviteLink()
                    }
                }
                Button("Отмена", role: .cancel) {
                    memberToExclude = nil
                    confirmsAvatarDelete = false
                    confirmsInviteReset = false
                }
            } message: {
                if confirmsInviteReset {
                    Text("Предыдущая ссылка перестанет работать. Новая будет скопирована в буфер обмена.")
                } else if confirmsAvatarDelete {
                    Text("Фотография беседы будет удалена.")
                } else {
                    Text("Участник потеряет доступ к беседе.")
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    private var chatDetailsSection: some View {
        Section(header: Text("Беседа")) {
            if model.canEditTitle {
                if #available(iOS 16.0, *) {
                    ChatAvatarPickerView(model: model)
                }
        
                if model.photoURL != nil {
                    Button(role: .destructive) {
                        confirmsAvatarDelete = true
                    } label: {
                        Label("Удалить фотографию", systemImage: "trash")
                    }
                }
            }
        
            TextField("Название", text: $title)
                .disabled(!model.canEditTitle)
        
            if model.canEditPermissions {
                Button {
                    showsPermissionsEditor = true
                } label: {
                    Label("Права участников", systemImage: "slider.horizontal.3")
                }
            }
        }
    }

    @ViewBuilder
    private var participantsSection: some View {
        if model.canAddMembers || !model.members.isEmpty {
            Section(header: Text("Участники")) {
                if model.canAddMembers {
                    Button {
                        showsAddMembers = true
                    } label: {
                        Label("Добавить участника", systemImage: "person.badge.plus")
                    }
                }
                ForEach(model.members) { member in
                    HStack(spacing: 10) {
                        Avatar(user: member.user, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.user.displayName)
                                .font(.subheadline)
                            if let role = member.roleTitle {
                                Text(role)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        if model.canAssign(member) || model.canExclude(member) {
                            Menu {
                                if model.canAssign(member) {
                                    Button {
                                        model.setModerator(member, enabled: !member.isModerator)
                                    } label: {
                                        Label(
                                            member.isModerator ? "Снять администратора" : "Назначить администратором",
                                            systemImage: member.isModerator ? "person.crop.circle.badge.minus" : "star"
                                        )
                                    }
                                }
                                if model.canExclude(member) {
                                    Button(role: .destructive) {
                                        memberToExclude = member
                                    } label: {
                                        Label("Исключить из беседы", systemImage: "person.crop.circle.badge.xmark")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var inviteSection: some View {
        if model.canSeeInviteLink || model.canRegenerateInviteLink {
            Section(header: Text("Ссылка-приглашение")) {
                if model.canSeeInviteLink {
                    Button {
                        model.copyInviteLink()
                    } label: {
                        Label("Скопировать ссылку", systemImage: "doc.on.doc")
                    }
                }
                if model.canRegenerateInviteLink {
                    Button(role: .destructive) {
                        confirmsInviteReset = true
                    } label: {
                        Label("Создать новую ссылку", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }

}

private struct ChatPermissionsEditorView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var model: ChatInfoViewModel
    @State private var draft: ChatPermissionSettings

    init(model: ChatInfoViewModel) {
        self.model = model
        _draft = State(initialValue: model.permissions)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    permissionRow("Приглашать участников", selection: $draft.invite)
                    permissionRow("Менять название и аватар", selection: $draft.changeInfo)
                    permissionRow("Закреплять сообщения", selection: $draft.changePin)
                    permissionRow("Использовать @all и @online", selection: $draft.useMassMentions)
                    permissionRow("Просматривать ссылку-приглашение", selection: $draft.seeInviteLink)
                    permissionRow("Обновлять ссылку-приглашение", selection: $draft.changeInviteLink)
                    permissionRow("Назначать администраторов", selection: $draft.changeAdmins,
                                  levels: [.admin, .owner])
                    permissionRow("Начинать звонки", selection: $draft.call)
                } footer: {
                    Text("Права применяются ко всем участникам беседы. Владелец всегда сохраняет полный доступ.")
                }
            }
            .navigationTitle("Права в беседе")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        model.updatePermissions(draft) { success in
                            if success { presentationMode.wrappedValue.dismiss() }
                        }
                    }
                    .disabled(!model.canEditPermissions || model.isWorking || draft == model.permissions)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func permissionRow(
        _ title: String,
        selection: Binding<ChatPermissionLevel>,
        levels: [ChatPermissionLevel] = ChatPermissionLevel.allCases
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(levels) { level in
                Text(level.title).tag(level)
            }
        }
        .pickerStyle(.menu)
    }
}

@available(iOS 16.0, *)
private struct ChatAvatarPickerView: View {
    @ObservedObject var model: ChatInfoViewModel
    @State private var selectedAvatar: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedAvatar, matching: .images) {
            VStack(spacing: 8) {
                Avatar(
                    user: User(
                        uid: model.conversation.id,
                        username: "",
                        displayName: model.title,
                        avatarURL: model.photoURL
                    ),
                    size: 82,
                    placeholderImageName: "chat_default_100",
                    isChat: true
                )
                Label("Изменить фотографию", systemImage: "camera")
                    .font(.footnote)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .disabled(model.isWorking)
        .onChange(of: selectedAvatar) { item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
                model.updateAvatar(jpeg)
            }
        }
    }
}

private struct ChatAddParticipantsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var model: ChatInfoViewModel
    @StateObject private var friends = CreateChatViewModel()
    @State private var query = ""
    @State private var selectedIDs: Set<Int> = []

    var body: some View {
        NavigationView {
            List {
                ForEach(friends.filteredFriends(for: query).filter { user in
                    guard let id = user.uid else { return false }
                    return !model.memberIDs.contains(id)
                }) { user in
                    Button {
                        guard let id = user.uid else { return }
                        if !selectedIDs.insert(id).inserted { selectedIDs.remove(id) }
                    } label: {
                        HStack(spacing: 12) {
                            Avatar(user: user, size: 40)
                            Text(user.displayName).foregroundStyle(.primary)
                            Spacer()
                            if let id = user.uid, selectedIDs.contains(id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Добавить участников")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Поиск...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Добавить") {
                        model.addUsers(Array(selectedIDs)) { success in
                            if success { presentationMode.wrappedValue.dismiss() }
                        }
                    }
                    .disabled(selectedIDs.isEmpty || model.isWorking)
                }
            }
            .onAppear { friends.loadFriends() }
        }
        .navigationViewStyle(.stack)
    }
}

private struct ChatMaterialPreviewView: View {
    @Environment(\.presentationMode) private var presentationMode
    let item: ChatMaterial

    var body: some View {
        NavigationView {
            Group {
                if let url = item.videoURL {
                    VideoPlayer(player: AVPlayer(url: url))
                } else if let url = item.photoURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                } else {
                    Text("Не удалось открыть материал")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
