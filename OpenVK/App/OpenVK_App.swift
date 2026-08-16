//
//  OpenVK_App.swift
//  OpenVK for iOS
//

import SwiftUI
import UserNotifications
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // todo из за того что мы вызываем при запуске AVAudio музыка на фоне останавливается
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure global AVAudioSession: \(error)")
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to configure global fallback AVAudioSession: \(error)")
            }
        }
        if #available(iOS 15.0, *) {
            UITableView.appearance().sectionHeaderTopPadding = 0
        }
        
        return true
    }
}

@main
struct OpenVKApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .onAppear {
                    requestNotificationPermissions()
                    if auth.isAuthenticated {
                        OnlineService.shared.start()
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        if auth.isAuthenticated {
                            OnlineService.shared.start()
                        }
                    case .inactive, .background:
                        OnlineService.shared.stop()
                    @unknown default:
                        break
                    }
                }
                .onChange(of: auth.isAuthenticated) { isAuth in
                    if isAuth && scenePhase == .active {
                        OnlineService.shared.start()
                    } else if !isAuth {
                        OnlineService.shared.stop()
                    }
                }
        }
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted.")
                AuthService.shared.updateAppIconBadge()
            } else if let error = error {
                print("Error requesting notification permissions: \(error.localizedDescription)")
            }
        }
    }
}
