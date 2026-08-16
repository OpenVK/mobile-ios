//
//  RootView.swift
//  OpenVK for iOS
//
//  Корневой контейнер.
//

import SwiftUI

/// Текст дисклеймера.
let appDisclaimer = "Данное мобильное приложение является клиентом для социальной сети OpenVK и с VK приложение никак не связан.\n\nOpenVK - социальная сеть с открытым исходным кодом, вдохновлённая ВКонтакте.\n\nOpenVK является любительской разработкой и никак не связан с ВКонтакте и компанией «VK Group» LCC"

struct RootView: View {

    @EnvironmentObject var auth: AuthService
    @AppStorage("openvk.theme_selection") private var themeSelection = 0
    @AppStorage("openvk.accent_color") private var accentColorName = "Синий"
    @State private var showDisclaimer = !UserDefaults.standard.bool(forKey: "openvk.disclaimer_shown")

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
            } else if auth.requiresTwoFactor {
                TwoFactorView()
            } else {
                LoginView()
            }
        }
        .environmentObject(auth)
        .accentColor(appAccentColor(for: accentColorName))
        .tint(appAccentColor(for: accentColorName))
        .id(accentColorName)
        .animation(.easeInOut, value: auth.isAuthenticated)
        .animation(.easeInOut, value: auth.requiresTwoFactor)
        .onAppear {
            applyTheme(themeSelection)
            SupportersService.shared.refreshIfNeeded()
        }
        .onChange(of: themeSelection) { selection in
            applyTheme(selection)
        }
        .alert(isPresented: $showDisclaimer) {
            Alert(
                title: Text("Важное предупреждение"),
                message: Text(appDisclaimer),
                dismissButton: .default(Text("Понятно")) {
                    UserDefaults.standard.set(true, forKey: "openvk.disclaimer_shown")
                }
            )
        }
    }

    private func applyTheme(_ selection: Int) {
        let style: UIUserInterfaceStyle
        switch selection {
        case 1: style = .light
        case 2: style = .dark
        default: style = .unspecified
        }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = style }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
