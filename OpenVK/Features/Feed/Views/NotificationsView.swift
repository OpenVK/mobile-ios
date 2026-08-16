//
//  NotificationsView.swift
//  OpenVK for iOS
//
//  Экран уведомлений.
//

import SwiftUI

private struct PostTarget: Hashable {
    let ownerId: Int
    let postId: Int
}

struct NotificationsView: View {
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?
    @State private var newNotifications: [AppNotification] = []
    @State private var archivedNotifications: [AppNotification] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    @State private var selectedUserTarget: User? = nil
    @State private var selectedPostTarget: PostTarget? = nil
    
    @State private var archivedOffset = 0
    @State private var isLoadingMoreArchived = false
    @State private var canLoadMoreArchived = true
    @State private var lastTriggeredNotificationID: UUID? = nil
    
    @Environment(\.presentationMode) var presentationMode

    init(selectedMedia: Binding<Attachment?> = .constant(nil), owningPost: Binding<Post?> = .constant(nil)) {
        self._selectedMedia = selectedMedia
        self._owningPost = owningPost
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(
                destination: Group {
                    if let target = selectedPostTarget {
                        PostDetailLoaderView(ownerID: target.ownerId, postID: target.postId, selectedMedia: $selectedMedia, owningPost: $owningPost)
                    }
                },
                isActive: Binding(
                    get: { selectedPostTarget != nil },
                    set: { if !$0 { selectedPostTarget = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()

            NavigationLink(
                destination: Group {
                    if let user = selectedUserTarget {
                        ProfileView(user: user, selectedMedia: $selectedMedia, owningPost: $owningPost)
                    }
                },
                isActive: Binding(
                    get: { selectedUserTarget != nil },
                    set: { if !$0 { selectedUserTarget = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()

            if let error = errorMessage {
                HStack {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        self.errorMessage = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.red.opacity(0.85))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            // Список уведомлений
            ZStack {
                List {
                    if newNotifications.isEmpty && archivedNotifications.isEmpty && !isLoading {
                        emptyState
                    } else {
                        if !newNotifications.isEmpty {
                            Section(header: Text(newNotificationsHeader(count: newNotifications.count)).font(.system(size: 13, weight: .semibold))) {
                                ForEach(newNotifications) { notification in
                                    NotificationRow(
                                        notification: notification,
                                        onAcceptFriend: {
                                            acceptFriendRequest(notification.id, isNew: true)
                                        },
                                        onDeclineFriend: {
                                            declineFriendRequest(notification.id, isNew: true)
                                        },
                                        onUserTap: { user in
                                            selectedUserTarget = user
                                        },
                                        onNotificationTap: { notif in
                                            handleNotificationTap(notif)
                                        }
                                    )
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                }
                            }
                        }
                        
                        if !archivedNotifications.isEmpty {
                            Section(header: Text("Просмотренные").font(.system(size: 13, weight: .semibold))) {
                                ForEach(archivedNotifications) { notification in
                                    NotificationRow(
                                        notification: notification,
                                        onAcceptFriend: {
                                            acceptFriendRequest(notification.id, isNew: false)
                                        },
                                        onDeclineFriend: {
                                            declineFriendRequest(notification.id, isNew: false)
                                        },
                                        onUserTap: { user in
                                            selectedUserTarget = user
                                        },
                                        onNotificationTap: { notif in
                                            handleNotificationTap(notif)
                                        }
                                    )
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .onAppear {
                                        if notification.id == archivedNotifications.last?.id {
                                            loadMoreArchivedNotifications()
                                        }
                                    }
                                }

                                if isLoadingMoreArchived {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .padding(.vertical, 12)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    AuthService.shared.fetchCounters()
                    loadNotifications()
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.4))
                }
            }
        }
        .navigationBarTitle("Уведомления", displayMode: .inline)
        .customBackButton(title: "Назад")
        .onAppear {
            if newNotifications.isEmpty && archivedNotifications.isEmpty {
                loadNotifications()
            }
        }
    }

    private func handleNotificationTap(_ notification: AppNotification) {
        if let postID = notification.targetPostID, let ownerID = notification.targetPostOwnerID {
            selectedPostTarget = PostTarget(ownerId: ownerID, postId: postID)
        } else {
            selectedUserTarget = notification.user
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(Color(.tertiaryLabel))
            Text("Уведомлений пока нет")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            Text("Здесь будут отображаться лайки, комментарии и заявки в друзья.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(minHeight: 300)
    }

    private func loadNotifications() {
        isLoading = true
        errorMessage = nil
        archivedOffset = 0
        canLoadMoreArchived = true
        lastTriggeredNotificationID = nil
        
        let group = DispatchGroup()
        
        var loadedNew: [AppNotification] = []
        var loadedArchived: [AppNotification] = []
        var loadedGifts: [VKUserGift] = []
        var fetchError: Error? = nil
        
        group.enter()
        NotificationsService.shared.fetchNotifications(archived: false, offset: 0, count: 20) { result in
            switch result {
            case .success(let items):
                loadedNew = items
            case .failure(let error):
                fetchError = error
            }
            group.leave()
        }
        
        group.enter()
        NotificationsService.shared.fetchNotifications(archived: true, offset: 0, count: 20) { result in
            switch result {
            case .success(let items):
                loadedArchived = items
            case .failure(let error):
                fetchError = error
            }
            group.leave()
        }
        
        group.enter()
        NotificationsService.shared.fetchGifts { result in
            switch result {
            case .success(let items):
                loadedGifts = items
            case .failure:
                break
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
            if let error = fetchError {
                self.errorMessage = error.localizedDescription
            } else {
                let mapGifts: (AppNotification) -> AppNotification = { notif in
                    if notif.type == .gift {
                        if let matchingGift = loadedGifts.min(by: {
                            abs(($0.date ?? 0) - notif.date.timeIntervalSince1970) < abs(($1.date ?? 0) - notif.date.timeIntervalSince1970)
                        }), abs((matchingGift.date ?? 0) - notif.date.timeIntervalSince1970) < 60.0 {
                            let imageUrl = matchingGift.gift?.thumb256.flatMap { URL(string: $0) } ?? matchingGift.gift?.thumb96.flatMap { URL(string: $0) }
                            let giftMessage = matchingGift.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? matchingGift.message : nil
                            
                            let user: User
                            if (matchingGift.fromId ?? 0) == 0 || matchingGift.privacy == 1 {
                                user = User(
                                    uid: 0,
                                    username: "anonymous_gift",
                                    displayName: "Аноним",
                                    avatarURL: nil
                                )
                            } else {
                                user = notif.user
                            }
                            
                            return AppNotification(
                                id: notif.id,
                                type: notif.type,
                                user: user,
                                postTextPreview: giftMessage,
                                createdAt: notif.createdAt,
                                isRead: notif.isRead,
                                ratingValue: notif.ratingValue,
                                giftImageURL: imageUrl,
                                date: notif.date,
                                targetPostID: notif.targetPostID,
                                targetPostOwnerID: notif.targetPostOwnerID
                            )
                        }
                    }
                    return notif
                }
                
                self.newNotifications = loadedNew.map(mapGifts)
                self.archivedNotifications = loadedArchived.map(mapGifts)
                self.archivedOffset = loadedArchived.count
                if loadedArchived.count < 20 {
                    self.canLoadMoreArchived = false
                }
                
                if !loadedNew.isEmpty {
                    AuthService.shared.notificationsCount = 0
                    NotificationsService.shared.markAsRead { _ in
                    }
                }
            }
        }
    }

    private func loadMoreArchivedNotifications() {
        guard !isLoading && !isLoadingMoreArchived && canLoadMoreArchived else { return }
        
        if let lastID = archivedNotifications.last?.id {
            if lastTriggeredNotificationID == lastID {
                return
            }
            lastTriggeredNotificationID = lastID
        }
        
        isLoadingMoreArchived = true
        let nextOffset = archivedOffset
        
        let group = DispatchGroup()
        var loadedMore: [AppNotification] = []
        var loadedGifts: [VKUserGift] = []
        
        group.enter()
        NotificationsService.shared.fetchNotifications(archived: true, offset: nextOffset, count: 20) { result in
            switch result {
            case .success(let items):
                loadedMore = items
            case .failure:
                break
            }
            group.leave()
        }
        
        group.enter()
        NotificationsService.shared.fetchGifts { result in
            switch result {
            case .success(let items):
                loadedGifts = items
            case .failure:
                break
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isLoadingMoreArchived = false
            if loadedMore.isEmpty {
                self.canLoadMoreArchived = false
            } else {
                let mapGifts: (AppNotification) -> AppNotification = { notif in
                    if notif.type == .gift {
                        if let matchingGift = loadedGifts.min(by: {
                            abs(($0.date ?? 0) - notif.date.timeIntervalSince1970) < abs(($1.date ?? 0) - notif.date.timeIntervalSince1970)
                        }), abs((matchingGift.date ?? 0) - notif.date.timeIntervalSince1970) < 60.0 {
                            let imageUrl = matchingGift.gift?.thumb256.flatMap { URL(string: $0) } ?? matchingGift.gift?.thumb96.flatMap { URL(string: $0) }
                            let giftMessage = matchingGift.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? matchingGift.message : nil
                            
                            let user: User
                            if (matchingGift.fromId ?? 0) == 0 || matchingGift.privacy == 1 {
                                user = User(
                                    uid: 0,
                                    username: "anonymous_gift",
                                    displayName: "Аноним",
                                    avatarURL: nil
                                )
                            } else {
                                user = notif.user
                            }
                            
                            return AppNotification(
                                id: notif.id,
                                type: notif.type,
                                user: user,
                                postTextPreview: giftMessage,
                                createdAt: notif.createdAt,
                                isRead: notif.isRead,
                                ratingValue: notif.ratingValue,
                                giftImageURL: imageUrl,
                                date: notif.date,
                                targetPostID: notif.targetPostID,
                                targetPostOwnerID: notif.targetPostOwnerID
                            )
                        }
                    }
                    return notif
                }
                
                let mapped = loadedMore.map(mapGifts)
                self.archivedNotifications.append(contentsOf: mapped)
                self.archivedOffset += loadedMore.count
                if loadedMore.count < 20 {
                    self.canLoadMoreArchived = false
                }
            }
        }
    }

    private func acceptFriendRequest(_ id: UUID, isNew: Bool) {
        withAnimation {
            if isNew {
                newNotifications.removeAll { $0.id == id }
            } else {
                archivedNotifications.removeAll { $0.id == id }
            }
        }
    }

    private func declineFriendRequest(_ id: UUID, isNew: Bool) {
        withAnimation {
            if isNew {
                newNotifications.removeAll { $0.id == id }
            } else {
                archivedNotifications.removeAll { $0.id == id }
            }
        }
    }

    private func newNotificationsHeader(count: Int) -> String {
        let remainder10 = count % 10
        let remainder100 = count % 100
        
        let word: String
        if remainder10 == 1 && remainder100 != 11 {
            word = "новое уведомление"
        } else if (remainder10 >= 2 && remainder10 <= 4) && (remainder100 < 10 || remainder100 >= 20) {
            word = "новых уведомления"
        } else {
            word = "новых уведомлений"
        }
        return "\(count) \(word)"
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification
    let onAcceptFriend: () -> Void
    let onDeclineFriend: () -> Void
    let onUserTap: (User) -> Void
    let onNotificationTap: (AppNotification) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { onUserTap(notification.user) }) {
                Avatar(user: notification.user, size: 44)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    notificationText(for: notification)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)

                    Spacer()

                    if !notification.isRead {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                    }
                }

                if notification.type == .friendRequest {
                    HStack(spacing: 8) {
                        Button(action: onAcceptFriend) {
                            Text("Добавить")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 90, height: 28)
                                .background(Color.appAccent)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: onDeclineFriend) {
                            Text("Скрыть")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 90, height: 28)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 4)
                }

                if let preview = notification.postTextPreview, notification.type != .friendRequest, notification.type != .makeAdmin {
                    Text(preview)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                if notification.type == .gift, let giftURL = notification.giftImageURL {
                    AsyncImage(url: giftURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                    } placeholder: {
                        ProgressView()
                            .frame(width: 80, height: 80)
                    }
                    .padding(.top, 4)
                }

                Text(notification.createdAt)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onNotificationTap(notification)
        }
    }

    @ViewBuilder
    private func notificationText(for notification: AppNotification) -> some View {
        let name = notification.user.displayName
        switch notification.type {
        case .like:
            Text("\(Text(name).bold()) оценил(а) вашу запись")
        case .comment:
            Text("\(Text(name).bold()) оставил(а) комментарий")
        case .friendRequest:
            Text("\(Text(name).bold()) хочет добавить вас в друзья")
        case .repost:
            Text("\(Text(name).bold()) поделился(ась) вашей записью")
        case .mention:
            Text("\(Text(name).bold()) упомянул(а) вас")
        case .wallPost:
            Text("\(Text(name).bold()) опубликовал(а) запись на вашей стене")
        case .gift:
            Text("\(Text(name).bold()) отправил(а) вам подарок")
        case .voicesTransfer:
            Text("\(Text(name).bold()) перевел(а) вам голоса")
        case .ratingUp:
            if let ratingValue = notification.ratingValue {
                Text("\(Text(name).bold()) повысил(а) вам рейтинг на \(ratingValue)")
            } else {
                Text("\(Text(name).bold()) повысил(а) вам рейтинг")
            }
        case .makeAdmin:
            if let groupName = notification.postTextPreview, !groupName.isEmpty {
                Text("\(Text(name).bold()) назначил(а) вас администратором в сообществе \(Text(groupName).bold())")
            } else {
                Text("\(Text(name).bold()) назначил(а) вас администратором")
            }
        }
    }
}

struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationsView()
        }
    }
}
