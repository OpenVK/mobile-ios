//
//  ProfileHeaderView.swift
//  OpenVK for iOS
//

import SwiftUI

struct ProfileHeaderView: View {

    let user: User
    @State private var isFriendLocal: Bool = false

    var isCurrentUser: Bool {
        user.isCurrentUser
    }

    private var isBanned: Bool {
        if case .banned = user.accessStatus {
            return true
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                Avatar(user: user, size: 76)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(user.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if user.isOfficial == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.appAccent)
                        }
                        SupporterBadgeView(screenName: user.username)
                    }

                    if user.isGroup != true {
                        if user.isOnline {
                            HStack(spacing: 4) {
                                Text("online")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                if let platform = user.onlinePlatform {
                                    PlatformIconView(platform: platform, size: 11, color: Color(.secondaryLabel))
                                }
                            }
                        } else if let lastSeen = user.lastSeen, !lastSeen.isEmpty {
                            HStack(spacing: 4) {
                                Text(lastSeen)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                if let platform = user.onlinePlatform {
                                    PlatformIconView(platform: platform, size: 11, color: Color(.secondaryLabel))
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if isCurrentUser {
                Button(action: {}) {
                    Text(L10n.Profile.edit)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.appAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else if user.accessStatus == .active || user.accessStatus == .privateProfile {
                HStack(spacing: 8) {
                    if user.isGroup == true {
                        Button(action: {
                            toggleGroupMembership()
                        }) {
                            HStack(spacing: 4) {
                                if isFriendLocal {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Вы подписаны")
                                } else {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Подписаться")
                                }
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isFriendLocal ? Color.primary : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(isFriendLocal ? Color(.secondarySystemBackground) : Color.appAccent)
                            .cornerRadius(8)
                        }
                    } else {
                        Button(action: {
                            withAnimation {
                                isFriendLocal.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                if isFriendLocal {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 18, height: 18, alignment: .center)
                                    Text("В друзьях")
                                } else {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 18, height: 18, alignment: .center)
                                        .offset(y: 0.5)
                                    Text("Добавить")
                                }
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isFriendLocal ? Color.primary : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(isFriendLocal ? Color(.secondarySystemBackground) : Color.appAccent)
                            .cornerRadius(8)
                        }

                        NavigationLink(destination: ChatView(conversation: Conversation(peer: user, lastMessage: ""))) {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Написать")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.appAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .onAppear {
                    isFriendLocal = user.isFriend ?? false
                }
                .onChange(of: user) { newUser in
                    isFriendLocal = newUser.isFriend ?? false
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private func toggleGroupMembership() {
        let originalState = isFriendLocal
        withAnimation {
            isFriendLocal.toggle()
        }
        
        let method = originalState ? "groups.leave" : "groups.join"
        let groupID = abs(user.uid ?? 0)
        
        APIClient.shared.call(
            method: method,
            parameters: ["group_id": "\(groupID)"],
            httpMethod: "POST",
            as: VKDefaultResponse.self
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print("Failed to \(method) group: \(error)")
                DispatchQueue.main.async {
                    withAnimation {
                        isFriendLocal = originalState
                    }
                }
            }
        }
    }
}
