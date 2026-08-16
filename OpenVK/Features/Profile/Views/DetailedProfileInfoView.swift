//
//  DetailedProfileInfoView.swift
//  OpenVK for iOS
//
//  Экран просмотра подробной информации профиля.
//

import SwiftUI

struct DetailedProfileInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    let user: User
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    InfoSection(title: "Основная информация") {
                        InfoRow(label: "Имя", value: user.displayName)
                        InfoRow(label: "Никнейм", value: "@\(user.username)")
                        if let status = user.status, !status.isEmpty {
                            InfoRow(label: "Статус", value: status)
                        }
                        if user.isGroup != true {
                            InfoRow(
                                label: "Активность",
                                value: user.isOnline ? "В сети" : (user.lastSeen ?? "Не в сети"),
                                platform: user.onlinePlatform
                            )
                        }
                    }
                    
                    if user.site != nil || user.city != nil {
                        InfoSection(title: "Контактная информация") {
                            if let site = user.site {
                                InfoRow(label: "Личный сайт", value: site, isLink: true)
                            }
                            if let city = user.city {
                                InfoRow(label: "Город", value: city)
                            }
                        }
                    }
                    
                    if let about = user.about, !about.isEmpty {
                        InfoSection(title: "Личная информация") {
                            InfoRow(label: "О себе", value: about)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitle("Подробная информация", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }
}

private struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(.secondaryLabel))
                .padding(.leading, 12)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var isLink: Bool = false
    var platform: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(Color(.secondaryLabel))
                    .frame(width: 110, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 14, weight: isLink ? .medium : .regular))
                        .foregroundColor(isLink ? .appAccent : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    if let platform = platform {
                        PlatformIconView(platform: platform, size: 11, color: Color(.secondaryLabel))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            Divider()
                .padding(.leading, 16)
        }
    }
}

struct DetailedProfileInfoView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DetailedProfileInfoView(user: .current)
                .preferredColorScheme(.light)
            DetailedProfileInfoView(user: .current)
                .preferredColorScheme(.dark)
        }
    }
}
