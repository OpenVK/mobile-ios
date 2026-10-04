//
//  ChatInfoView.swift
//  OpenVK for iOS
//

import SwiftUI
import AVKit

struct ChatInfoView: View {
    private enum ActiveAlert: Identifiable {
        case unavailable
        case error(String)

        var id: String {
            switch self {
            case .unavailable: return "unavailable"
            case .error(let message): return "error:\(message)"
            }
        }
    }

    @StateObject private var model: ChatInfoViewModel
    @State private var showsAddMembers = false
    @State private var activeAlert: ActiveAlert?
    @State private var memberToExclude: ChatMember?
    @State private var preview: ChatMaterial?

    init(conversation: Conversation) {
        _model = StateObject(wrappedValue: ChatInfoViewModel(conversation: conversation))
    }

    var body: some View {
        List {
            header
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            settingsRow
            sectionPicker
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            sectionContent(model.selectedSection)
        }
        .listStyle(.plain)
        .navigationTitle("Информация о беседе")
        .navigationBarTitleDisplayMode(.inline)
        .chatTabBarHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if model.canEdit {
                    Button("Изм.") {}
                }
            }
        }
        .onAppear { model.load() }
        .onChange(of: model.selectedSection) { model.loadMaterials($0) }
        .onChange(of: model.errorMessage) { message in
            if let message { activeAlert = .error(message) }
        }
        .sheet(isPresented: $showsAddMembers) {
            ChatAddParticipantsView(model: model)
        }
        .sheet(item: $preview) { item in
            ChatMaterialPreviewView(item: item)
        }
        .confirmationDialog(
            "Исключить участника из беседы?",
            isPresented: Binding(
                get: { memberToExclude != nil },
                set: { if !$0 { memberToExclude = nil } }
            )
        ) {
            if let memberToExclude {
                Button("Исключить \(memberToExclude.user.displayName)", role: .destructive) {
                    model.exclude(memberToExclude)
                    self.memberToExclude = nil
                }
            }
            Button("Отмена", role: .cancel) { memberToExclude = nil }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .unavailable:
                return Alert(
                    title: Text("В разработке"),
                    message: Text("Раздел находится в разработке и будет доступен в следующих версиях."),
                    dismissButton: .cancel(Text("ОК"))
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
                user: User(
                    uid: model.conversation.id,
                    username: "",
                    displayName: model.title,
                    avatarURL: model.photoURL
                ),
                size: 92,
                placeholderImageName: "chat_default_100",
                isChat: true
            )
            .padding(.top, 12)

            Text(model.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text("\(model.memberCount) \(memberCountWord(model.memberCount))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                Button {
                    model.toggleMute()
                } label: {
                    actionLabel(title: "Звук", icon: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .accessibilityValue(model.isMuted ? "Выключен" : "Включён")

                Button {
                    activeAlert = .unavailable
                } label: {
                    actionLabel(title: "Поиск", icon: "magnifyingglass")
                }

                Button {
                    activeAlert = .unavailable
                } label: {
                    actionLabel(title: "Ещё", icon: "ellipsis")
                }
                .accessibilityLabel("Ещё")
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var settingsRow: some View {
        Button { activeAlert = .unavailable } label: {
            HStack {
                SettingsRow(icon: "gearshape", title: "Настройка беседы", iconColor: .gray)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                ForEach(ChatMaterialSection.allCases) { section in
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
