//
//  AppConfig.swift
//  OpenVK for iOS
//
//  Конфигурация окружения.
//

import Foundation

enum InstanceOption: String, CaseIterable, Identifiable, Codable {
    case apiOpenVK = "api.openvk.org"
    case openvkXYZ = "openvk.xyz"
    case vepurovkXYZ = "vepurovk.xyz"
    case apiVepurovkFun = "api.vepurovk.fun"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apiOpenVK: return "api.openvk.org"
        case .openvkXYZ: return "openvk.xyz"
        case .vepurovkXYZ: return "vepurovk.xyz"
        case .apiVepurovkFun: return "api.vepurovk.fun"
        case .custom: return L10n.Auth.customInstance
        }
    }
}

enum AppConfig {
    private static let instanceOptionKey = "openvk.instance_option"
    private static let customInstanceHostKey = "openvk.custom_instance_host"

    static var currentInstanceOption: InstanceOption {
        get {
            if let saved = UserDefaults.standard.string(forKey: instanceOptionKey),
               let option = InstanceOption(rawValue: saved) {
                return option
            }
            return .apiOpenVK
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: instanceOptionKey)
        }
    }

    static var customInstanceHost: String {
        get {
            UserDefaults.standard.string(forKey: customInstanceHostKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: customInstanceHostKey)
        }
    }

    static var currentHost: String {
        let option = currentInstanceOption
        if option == .custom {
            let customHost = customInstanceHost.trimmingCharacters(in: .whitespacesAndNewlines)
            return customHost.isEmpty ? InstanceOption.apiOpenVK.rawValue : customHost
        }
        return option.rawValue
    }

    static var apiBaseURL: URL {
        var raw = currentHost
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            raw = "https://" + raw
        }
        if !raw.hasSuffix("/") {
            raw += "/"
        }
        return URL(string: raw) ?? URL(string: "https://api.openvk.org/")!
    }

    static var webBaseURL: URL {
        guard let host = apiBaseURL.host else { return apiBaseURL }
        var webHost = host
        if webHost.lowercased().hasPrefix("api.") {
            webHost = String(webHost.dropFirst(4))
        }
        return URL(string: "https://" + webHost + "/") ?? apiBaseURL
    }

    static let appName = "OpenVK"

    static var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }
}
