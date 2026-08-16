//
//  RepostView.swift
//  OpenVK for iOS
//
//  Экран «Поделиться»
//

import SwiftUI

struct HalfSheet: ViewModifier {
    var compact: Bool = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents(compact ? [.height(300), .medium, .large] : [.medium, .large])
                .presentationDragIndicator(.visible)
        } else if #available(iOS 15.0, *) {
            content.background(SheetDetentsConfigurator())
        } else {
            content
        }
    }
}

@available(iOS 15.0, *)
struct SheetDetentsConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let sheet = uiView.nearestSheetPresentationController else { return }
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
    }
}

@available(iOS 15.0, *)
private extension UIView {
    var nearestSheetPresentationController: UISheetPresentationController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let controller = next as? UIViewController {
                return controller.sheetPresentationController
            }
            responder = next
        }
        return nil
    }
}

enum RepostMode {
    case chat
    case myWall
    case group
}

struct ShareRecipient: Identifiable {
    let id: Int
    let user: User
    let subtitle: String
}

struct RepostGroup: Hashable, Identifiable {
    let id: Int
    let name: String
    let memberCount: Int
    let photoURL: URL?
}

struct RepostView: View {

    let post: Post
    var onComplete: (Int?) -> Void = { _ in }

    @Environment(\.presentationMode) private var presentationMode

    @State private var mode: RepostMode = .chat

    @State private var searchText = ""
    @State private var conversations: [ShareRecipient] = []
    @State private var friends: [ShareRecipient] = []
    @State private var isLoadingChats = true
    @State private var chatsErrorMessage: String? = nil

    @State private var groups: [RepostGroup] = []
    @State private var isLoadingGroups = false
    @State private var groupsErrorMessage: String? = nil

    @State private var comment = ""
    @State private var asGroup = false
    @State private var signed = false

    @State private var sendingPeerID: Int? = nil
    @State private var isSendingWall = false
    @State private var errorMessage: String? = nil
    @State private var showError = false

    @State private var sentPeerIDs: Set<Int> = []
    @State private var showGroupOptions = false

    private var postLink: String {
        let ownerID = post.ownerID ?? post.author.uid ?? 0
        let vkID = post.vkID ?? 0
        return AppConfig.webBaseURL.absoluteString + "wall\(ownerID)_\(vkID)"
    }

    private var chatMessage: String {
        let linkLine = "> \(postLink)"
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return linkLine
        }
        return linkLine + "\n" + trimmed
    }

    private var conversationIDs: Set<Int> {
        Set(conversations.map { $0.id })
    }

    private var visibleRecipients: [ShareRecipient] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return conversations }
        let matches: (ShareRecipient) -> Bool = { recipient in
            recipient.user.displayName.lowercased().contains(query) ||
                recipient.user.username.lowercased().contains(query)
        }
        let chatMatches = conversations.filter(matches)
        let friendMatches = friends.filter { !conversationIDs.contains($0.id) }
        return chatMatches + friendMatches.filter(matches)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if mode != .myWall {
                    contentArea

                    Divider()
                }

                messageInput
                actionRow
            }
            .navigationBarTitle("Поделиться", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Отмена") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Ошибка"),
                    message: Text(errorMessage ?? "Не удалось поделиться"),
                    dismissButton: .default(Text("ОК"))
                )
            }
            .sheet(isPresented: $showGroupOptions) {
                groupOptionsSheet
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .modifier(HalfSheet(compact: mode == .myWall))
        .onAppear {
            loadChats()
            loadAdminGroups()
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        switch mode {
        case .chat:
            chatArea
        case .myWall:
            EmptyView()
        case .group:
            groupArea
        }
    }

    private var chatArea: some View {
        VStack(spacing: 0) {
            searchField

            if isLoadingChats {
                Spacer()
                LongLoadingIndicator(message: "Насколько сильно любите диалоги в опенвк? Я очень... :)", timeout: 5.0)
                Spacer()
            } else if let error = chatsErrorMessage {
                Spacer()
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            } else {
                List(visibleRecipients) { recipient in
                    recipientRow(recipient)
                }
                .listStyle(PlainListStyle())
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            TextField("Поиск чатов и друзей", text: $searchText)
                .font(.system(size: 15))
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func recipientRow(_ recipient: ShareRecipient) -> some View {
        HStack(spacing: 12) {
            Avatar(user: recipient.user, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(recipient.user.displayName)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(recipient.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            sendRowButton(
                isSent: sentPeerIDs.contains(recipient.id),
                isSending: sendingPeerID == recipient.id,
                action: { sendToChat(recipient) }
            )
        }
        .padding(.vertical, 2)
    }

    private func sendRowButton(isSent: Bool,
                               isSending: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isSending {
                    ProgressView()
                } else if isSent {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Отправлено")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        Capsule()
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                } else {
                    Text("Отправить")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            Capsule()
                                .stroke(Color.appAccent, lineWidth: 1)
                        )
                }
            }
            .frame(minWidth: 60)
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(isSending || isSent)
    }

    private var groupArea: some View {
        VStack(spacing: 0) {
            if isLoadingGroups {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = groupsErrorMessage {
                Spacer()
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            } else if groups.isEmpty {
                Spacer()
                Text("Нет сообществ, где вы администратор")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            } else {
                List(groups) { group in
                    groupRow(group)
                }
                .listStyle(PlainListStyle())
            }
        }
    }

    private func groupRow(_ group: RepostGroup) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                if let photoURL = group.photoURL {
                    RemoteImage(url: photoURL, placeholder: Image(systemName: "person.3.fill"))
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(.secondaryLabel))
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("\(group.memberCount) участников")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            sendRowButton(
                isSent: sentPeerIDs.contains(group.id),
                isSending: sendingPeerID == group.id,
                action: { sendToGroup(group) }
            )
        }
        .padding(.vertical, 2)
    }

    private var groupOptionsSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Опции публикации")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button("Готово") {
                    showGroupOptions = false
                }
                .font(.system(size: 15))
                .padding(.trailing, 16)
            }
            .padding(.vertical, 12)

            Divider()

            Toggle(isOn: $asGroup) {
                Text("От имени группы")
                    .font(.system(size: 15))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .padding(.leading, 16)

            Toggle(isOn: $signed) {
                Text("Подпись автора")
                    .font(.system(size: 15))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Text("При публикации на стене группы запись появится от его имени.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 6)

            Spacer(minLength: 0)
        }
        .background(Color(.systemBackground))
        .modifier(HalfSheet())
    }

    private var messageInput: some View {
        HStack(spacing: 10) {
            TextField("Добавить сообщение", text: $comment)
                .font(.system(size: 15))
            messageInputTrailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var messageInputTrailing: some View {
        switch mode {
        case .chat:
            EmptyView()
        case .myWall:
            Button(action: publishToWall) {
                Group {
                    if isSendingWall {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                    } else {
                        Text("Отправить")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appAccent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .overlay(
                                Capsule()
                                    .stroke(Color.appAccent, lineWidth: 1)
                            )
                    }
                }
            }
            .disabled(isSendingWall)
        case .group:
            Button {
                showGroupOptions = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 0) {
            shareAction(icon: "person.fill",
                        title: "На своей странице",
                        isSelected: mode == .myWall) {
                withAnimation {
                    mode = mode == .myWall ? .chat : .myWall
                }
            }
            shareAction(icon: "person.2.fill",
                        title: "На стене группы",
                        isSelected: mode == .group) {
                withAnimation {
                    mode = mode == .group ? .chat : .group
                }
            }
            shareAction(icon: "link",
                        title: "Скопировать ссылку",
                        isSelected: false) {
                copyLink()
            }
            shareAction(icon: "square.and.arrow.up",
                        title: "Другое",
                        isSelected: false) {
                openSystemShare()
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func shareAction(icon: String,
                             title: String,
                             isSelected: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .appAccent : Color(.secondaryLabel))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .appAccent : Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loadChats() {
        isLoadingChats = true
        chatsErrorMessage = nil

        let group = DispatchGroup()

        group.enter()
        MessagesService.shared.fetchConversations(offset: 0, count: 30) { result in
            defer { group.leave() }
            switch result {
            case .success(let items):
                conversations = items.map { conversation in
                    ShareRecipient(
                        id: conversation.peer.uid ?? 0,
                        user: conversation.peer,
                        subtitle: "@\(conversation.peer.username)"
                    )
                }
            case .failure(let error):
                chatsErrorMessage = error.localizedDescription
            }
        }

        group.enter()
        let ownerID = AuthService.shared.currentUser?.uid ?? 0
        APIClient.shared.call(
            method: "friends.get",
            parameters: [
                "user_id": "\(ownerID)",
                "fields": "photo_100,online,last_seen",
                "count": "100"
            ],
            httpMethod: "GET",
            as: VKSearchResponseInner<VKUserProfile>.self
        ) { result in
            defer { group.leave() }
            switch result {
            case .success(let inner):
                friends = (inner.items ?? []).map { vkUser -> ShareRecipient in
                    let id = vkUser.id
                    let name = "\(vkUser.firstName ?? "") \(vkUser.lastName ?? "")"
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return ShareRecipient(
                        id: id,
                        user: User(
                            uid: id,
                            username: vkUser.screenName ?? "id\(id)",
                            displayName: name.isEmpty ? "Пользователь" : name,
                            avatarURL: vkUser.photo100.flatMap { URL(string: $0) },
                            isOnline: vkUser.online == 1,
                            onlinePlatform: vkUser.lastSeen?.platformName
                        ),
                        subtitle: "@\(vkUser.screenName ?? "id\(id)")"
                    )
                }
            case .failure(let error):
                if chatsErrorMessage == nil {
                    chatsErrorMessage = error.localizedDescription
                }
            }
        }

        group.notify(queue: .main) {
            isLoadingChats = false
        }
    }

    private func loadAdminGroups() {
        isLoadingGroups = true
        groupsErrorMessage = nil

        APIClient.shared.call(
            method: "groups.get",
            parameters: [
                "filter": "admin",
                "extended": "1",
                "fields": "name,photo_100,members_count",
                "count": "100"
            ],
            httpMethod: "GET",
            as: VKGroupsResponseInner.self
        ) { result in
            isLoadingGroups = false
            switch result {
            case .success(let inner):
                groups = (inner.items ?? []).compactMap { item -> RepostGroup? in
                    guard let id = item.id else { return nil }
                    return RepostGroup(
                        id: id,
                        name: item.name ?? "Сообщество",
                        memberCount: item.membersCount ?? 0,
                        photoURL: item.photo100.flatMap { URL(string: $0) }
                    )
                }
            case .failure(let error):
                groupsErrorMessage = "Не удалось загрузить группы"
                print("Failed to load admin groups: \(error)")
            }
        }
    }

    private func sendToChat(_ recipient: ShareRecipient) {
        guard sendingPeerID == nil else { return }
        sendingPeerID = recipient.id
        errorMessage = nil

        MessagesService.shared.send(text: chatMessage, to: recipient.id) { result in
            sendingPeerID = nil
            switch result {
            case .success:
                HapticManager.impact(.medium)
                sentPeerIDs.insert(recipient.id)
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func publishToWall() {
        guard !isSendingWall else { return }
        isSendingWall = true
        errorMessage = nil

        FeedService.shared.repost(
            object: repostObject,
            message: comment,
            groupID: nil,
            asGroup: false,
            signed: false
        ) { result in
            isSendingWall = false
            switch result {
            case .success(let repostsCount):
                HapticManager.impact(.medium)
                onComplete(repostsCount)
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func sendToGroup(_ group: RepostGroup) {
        guard sendingPeerID == nil else { return }
        sendingPeerID = group.id
        errorMessage = nil

        FeedService.shared.repost(
            object: repostObject,
            message: comment,
            groupID: group.id,
            asGroup: asGroup,
            signed: signed
        ) { result in
            sendingPeerID = nil
            switch result {
            case .success(let repostsCount):
                HapticManager.impact(.medium)
                sentPeerIDs.insert(group.id)
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private var repostObject: String {
        let ownerID = post.ownerID ?? post.author.uid ?? 0
        let vkID = post.vkID ?? 0
        return "wall\(ownerID)_\(vkID)"
    }

    private func copyLink() {
        UIPasteboard.general.string = postLink
        HapticManager.impact(.medium)
        presentationMode.wrappedValue.dismiss()
    }

    private func openSystemShare() {
        let av = UIActivityViewController(activityItems: [postLink], applicationActivities: nil)
        if let topVC = getTopmostViewController() {
            if let popover = av.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topVC.present(av, animated: true, completion: nil)
        }
    }
}
