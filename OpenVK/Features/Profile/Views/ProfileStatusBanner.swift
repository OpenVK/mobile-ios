//
//  ProfileStatusBanner.swift
//  OpenVK for iOS
//
//  Информационная плашка для удаленных, заблокированных, закрытых профилей и ЧС.
//

import SwiftUI

struct ProfileStatusBanner: View {
    let status: ProfileAccessStatus
    let user: User

    var body: some View {
        VStack(spacing: 14) {
            if case .banned = status {
                Image("oof")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, 4)
            } else {
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor.opacity(0.12))
                        .frame(width: 60, height: 60)

                    Image(systemName: iconName)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                .padding(.top, 8)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var iconName: String {
        switch status {
        case .deleted:
            return "person.crop.circle.badge.xmark"
        case .banned:
            return "exclamationmark.shield.fill"
        case .blacklistedByThem:
            return "hand.raised.fill"
        case .blacklistedByMe:
            return "person.fill.xmark"
        case .privateProfile:
            return "lock.fill"
        case .active:
            return "info.circle"
        }
    }

    private var iconColor: Color {
        switch status {
        case .deleted:
            return .secondary
        case .banned:
            return .red
        case .blacklistedByThem:
            return .orange
        case .blacklistedByMe:
            return .secondary
        case .privateProfile:
            return Color.appAccent
        case .active:
            return Color.appAccent
        }
    }

    private var iconBackgroundColor: Color {
        switch status {
        case .deleted:
            return .secondary
        case .banned:
            return .red
        case .blacklistedByThem:
            return .orange
        case .blacklistedByMe:
            return .secondary
        case .privateProfile:
            return Color.appAccent
        case .active:
            return Color.appAccent
        }
    }

    private var title: String {
        switch status {
        case .deleted:
            return "Страница удалена"
        case .banned:
            return "Страница заблокирована"
        case .blacklistedByThem:
            return "Доступ ограничен"
        case .blacklistedByMe:
            return "Пользователь в чёрном списке"
        case .privateProfile:
            return "Это закрытый профиль"
        case .active:
            return ""
        }
    }

    private var subtitle: String {
        switch status {
        case .deleted:
            return "Информация о пользователе недоступна."
        case .banned(let reason):
            var lines: [String] = []
            if let expires = user.banExpires, !expires.isEmpty {
                lines.append("Заблокирован\(genderSuffix) до: \(expires)")
            }
            if let reason = reason, !reason.isEmpty {
                lines.append("Причина блокировки: \(reason)")
            }
            if lines.isEmpty {
                return "Страница пользователя заблокирована за нарушение правил."
            } else {
                return lines.joined(separator: "\n")
            }
        case .blacklistedByThem:
            return "\(user.displayName) ограничил\(user.sex == 1 ? "а" : (user.sex == 2 ? "" : "(а)")) доступ к своей странице."
        case .blacklistedByMe:
            return "Вы добавили этого пользователя в свой чёрный список."
        case .privateProfile:
            return "Добавьте \(user.displayName) в друзья, чтобы просматривать записи, фотографии и подробную информацию."
        case .active:
            return ""
        }
    }

    private var genderSuffix: String {
        if user.sex == 1 {
            return "а"
        } else if user.sex == 2 {
            return ""
        } else {
            return "(а)"
        }
    }
}
