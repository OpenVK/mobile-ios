//
//  AuthService.swift
//  OpenVK for iOS
//
//  Управление сессией пользователя.
//

import Foundation
import UIKit
import Combine
import OSLog

private let authLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "openvk", category: "AuthService")

extension Notification.Name {
    static let openvkAccountDidChange = Notification.Name("openvk.accountDidChange")
}

final class AuthService: ObservableObject {

    static let shared = AuthService()

    @Published private(set) var isAuthenticated: Bool = false
    var isAuthorized: Bool { isAuthenticated }
    @Published var requiresTwoFactor: Bool = false
    @Published private(set) var currentUser: User?
    @Published private(set) var accounts: [AuthAccount] = []

    @Published var friendsCount: Int = 0 {
        didSet { updateAppIconBadge() }
    }
    @Published var notificationsCount: Int = 0 {
        didSet { updateAppIconBadge() }
    }
    @Published var messagesCount: Int = 0 {
        didSet { updateAppIconBadge() }
    }
    @Published var balanceVotes: Int = 0
    @Published var isBalanceLoading: Bool = false

    private(set) var token: String?
    private var pendingToken: String?

    private var emailDraft: String?
    private var passwordDraft: String?

    private let tokenKey = "openvk.token"

    init() {
        var loadedAccounts: [AuthAccount] = []
        if let data = UserDefaults.standard.data(forKey: "openvk.accounts"),
           let decoded = try? JSONDecoder().decode([AuthAccount].self, from: data) {
            loadedAccounts = decoded
        }

        if loadedAccounts.isEmpty,
           let storedToken = UserDefaults.standard.string(forKey: tokenKey),
           !storedToken.isEmpty {
            let userObj: User
            if let userData = UserDefaults.standard.data(forKey: "openvk.current_user"),
               let decodedUser = try? JSONDecoder().decode(User.self, from: userData) {
                userObj = decodedUser
            } else {
                userObj = .current
            }

            let legacyAccount = AuthAccount(
                user: userObj,
                token: storedToken,
                instanceOption: AppConfig.currentInstanceOption,
                customInstanceHost: AppConfig.customInstanceHost
            )
            loadedAccounts = [legacyAccount]
            if let encoded = try? JSONEncoder().encode(loadedAccounts) {
                UserDefaults.standard.set(encoded, forKey: "openvk.accounts")
            }
        }

        self.accounts = loadedAccounts

        if let activeToken = UserDefaults.standard.string(forKey: tokenKey), !activeToken.isEmpty {
            self.token = activeToken
            self.isAuthenticated = true

            if let activeAccount = loadedAccounts.first(where: { $0.token == activeToken }) {
                AppConfig.currentInstanceOption = activeAccount.instanceOption
                AppConfig.customInstanceHost = activeAccount.customInstanceHost
            }

            DispatchQueue.main.async {
                self.fetchCounters()
            }

            if let userData = UserDefaults.standard.data(forKey: "openvk.current_user"),
               let decodedUser = try? JSONDecoder().decode(User.self, from: userData) {
                self.currentUser = decodedUser

                if decodedUser.uid == nil || decodedUser.uid == 0 || decodedUser.isOfficial == nil {
                    fetchUserProfile(token: activeToken) { [weak self] result in
                        if case .success(let user) = result {
                            DispatchQueue.main.async {
                                self?.currentUser = user
                                if let encoded = try? JSONEncoder().encode(user) {
                                    UserDefaults.standard.set(encoded, forKey: "openvk.current_user")
                                }
                                self?.updateAccountUser(user)
                            }
                        }
                    }
                }
            } else {
                self.currentUser = .current
                fetchUserProfile(token: activeToken) { [weak self] result in
                    if case .success(let user) = result {
                        DispatchQueue.main.async {
                            self?.currentUser = user
                            if let encoded = try? JSONEncoder().encode(user) {
                                UserDefaults.standard.set(encoded, forKey: "openvk.current_user")
                            }
                            self?.updateAccountUser(user)
                        }
                    }
                }
            }
        }
    }

    func signIn(email: String,
                password: String,
                completion: @escaping (Result<Void, AuthError>) -> Void) {
        requestToken(email: email, password: password, code: nil, completion: completion)
    }

    func verifyTwoFactor(code: String, completion: @escaping (Result<Void, AuthError>) -> Void) {
        guard let email = emailDraft, let password = passwordDraft else {
            completion(.failure(.invalidCredentials))
            return
        }
        requestToken(email: email, password: password, code: code, completion: completion)
    }

    func changeCurrentUser(to user: User) {
        if let targetAccount = accounts.first(where: { $0.user.username == user.username }) {
            switchToAccount(targetAccount)
        }
    }

    func switchToAccount(_ account: AuthAccount) {
        AppConfig.currentInstanceOption = account.instanceOption
        AppConfig.customInstanceHost = account.customInstanceHost

        self.token = account.token
        self.currentUser = account.user

        UserDefaults.standard.set(account.token, forKey: tokenKey)
        if let encoded = try? JSONEncoder().encode(account.user) {
            UserDefaults.standard.set(encoded, forKey: "openvk.current_user")
        }

        self.isAuthenticated = true
        self.requiresTwoFactor = false

        CacheService.shared.clearAll()
        NotificationCenter.default.post(name: .openvkAccountDidChange, object: nil)

        fetchCounters()
    }

    func removeAccount(byUsername username: String) {
        let isActive = (currentUser?.username == username)

        accounts.removeAll { $0.user.username == username }
        saveAccounts()

        if isActive {
            if let nextAccount = accounts.first {
                switchToAccount(nextAccount)
            } else {
                signOutAll()
            }
        }
    }

    func signOutAll() {
        token = nil
        pendingToken = nil
        currentUser = nil
        isAuthenticated = false
        requiresTwoFactor = false
        emailDraft = nil
        passwordDraft = nil
        accounts = []

        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: "openvk.current_user")
        UserDefaults.standard.removeObject(forKey: "openvk.accounts")

        CacheService.shared.clearAll()
        NotificationCenter.default.post(name: .openvkAccountDidChange, object: nil)
    }

    func signOut() {
        if let activeUsername = currentUser?.username {
            removeAccount(byUsername: activeUsername)
        } else {
            signOutAll()
        }
    }

    func fetchCounters() {
        guard isAuthenticated else { return }

        APIClient.shared.call(
            method: "account.getCounters",
            parameters: [:],
            httpMethod: "GET",
            as: VKCountersResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.friendsCount = response.friends ?? 0
                    self?.notificationsCount = response.notifications ?? 0
                    self?.messagesCount = response.messages ?? 0
                case .failure(let error):
                    print("Failed to fetch counters: \(error.localizedDescription)")
                }
            }
        }
    }

    func fetchBalance() {
        guard isAuthenticated else { return }
        isBalanceLoading = true

        APIClient.shared.call(
            method: "account.getBalance",
            parameters: [:],
            httpMethod: "GET",
            as: VKBalanceResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isBalanceLoading = false
                switch result {
                case .success(let response):
                    self?.balanceVotes = response.votes
                case .failure(let error):
                    print("Failed to fetch balance: \(error.localizedDescription)")
                }
            }
        }
    }

    func updateAppIconBadge() {
        let showMessages = UserDefaults.standard.object(forKey: "badge_msg") as? Bool ?? true
        let showNotifications = UserDefaults.standard.object(forKey: "badge_notify") as? Bool ?? true
        let showFriends = UserDefaults.standard.object(forKey: "badge_friend") as? Bool ?? true

        var totalBadge = 0
        if showMessages { totalBadge += messagesCount }
        if showNotifications { totalBadge += notificationsCount }
        if showFriends { totalBadge += friendsCount }

        UIApplication.shared.applicationIconBadgeNumber = totalBadge
    }

    private func saveAccounts() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: "openvk.accounts")
        }
    }

    private func updateAccountUser(_ user: User) {
        if let idx = accounts.firstIndex(where: { $0.user.username == user.username }) {
            let currentAccount = accounts[idx]
            accounts[idx] = AuthAccount(
                user: user,
                token: currentAccount.token,
                instanceOption: currentAccount.instanceOption,
                customInstanceHost: currentAccount.customInstanceHost
            )
            saveAccounts()
        }
    }

    private func requestToken(email: String,
                              password: String,
                              code: String?,
                              completion: @escaping (Result<Void, AuthError>) -> Void) {
        let host = AppConfig.currentHost
        var raw = host
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            raw = "https://" + raw
        }
        if !raw.hasSuffix("/") { raw += "/" }

        var queryItems = [
            URLQueryItem(name: "username", value: email),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "grant_type", value: "password"),
            URLQueryItem(name: "client_name", value: "openvk_ios")
        ]
        if let code = code {
            queryItems.append(URLQueryItem(name: "code", value: code))
        }

        var urlComponents = URLComponents(string: raw + "token")!
        urlComponents.queryItems = queryItems

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")

        var formComponents = URLComponents()
        formComponents.queryItems = queryItems
        if let percentEncodedQuery = formComponents.percentEncodedQuery {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = percentEncodedQuery.data(using: .utf8)
        }

#if DEBUG
        let maskedURL = urlComponents.url!.absoluteString.replacingOccurrences(of: password, with: "***")
        let maskedBody = request.httpBody.flatMap { String(data: $0, encoding: .utf8)?.replacingOccurrences(of: password, with: "***") } ?? "nil"
        os_log("[Token Request] %{public}@ %{public}@ body: %{public}@", log: authLog, type: .debug, request.httpMethod ?? "POST", maskedURL, maskedBody)
#endif

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            let failOnMain: (AuthError) -> Void = { err in
                DispatchQueue.main.async { completion(.failure(err)) }
            }

            if error != nil { failOnMain(.network); return }

            guard let http = response as? HTTPURLResponse else { failOnMain(.network); return }
            guard let data = data else { failOnMain(.network); return }

            if let errJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let errorStr = errJSON["error"] as? String

                if errorStr == "need_validation" {
                    if code == nil {
                        DispatchQueue.main.async {
                            self.emailDraft = email
                            self.passwordDraft = password
                            self.requiresTwoFactor = true
                            completion(.success(()))
                        }
                        return
                    } else {
                        failOnMain(.invalidCredentials)
                        return
                    }
                }
            }

            guard (200..<300).contains(http.statusCode) else {
                failOnMain(.invalidCredentials)
                return
            }

            struct TokenResponse: Decodable {
                let access_token: String
                let user_id: Int
            }

            do {
                let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
                let tokenToSave = decoded.access_token

                self.fetchUserProfile(token: tokenToSave) { userResult in
                    DispatchQueue.main.async {
                        switch userResult {
                        case .success(let user):
                            self.token = tokenToSave
                            UserDefaults.standard.set(tokenToSave, forKey: self.tokenKey)

                            if let encoded = try? JSONEncoder().encode(user) {
                                UserDefaults.standard.set(encoded, forKey: "openvk.current_user")
                            }

                            let newAccount = AuthAccount(
                                user: user,
                                token: tokenToSave,
                                instanceOption: AppConfig.currentInstanceOption,
                                customInstanceHost: AppConfig.customInstanceHost
                            )
                            self.accounts.removeAll { $0.user.username == user.username }
                            self.accounts.append(newAccount)
                            self.saveAccounts()

                            self.currentUser = user
                            self.requiresTwoFactor = false
                            self.isAuthenticated = true
                            self.emailDraft = nil
                            self.passwordDraft = nil
                            self.fetchCounters()
                            NotificationCenter.default.post(name: .openvkAccountDidChange, object: nil)
                            completion(.success(()))
                        case .failure:
                            completion(.failure(.network))
                        }
                    }
                }
            } catch {
                failOnMain(.invalidCredentials)
            }
        }.resume()
    }

    private func fetchUserProfile(token: String, completion: @escaping (Result<User, Error>) -> Void) {
        let host = AppConfig.currentHost
        var raw = host
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            raw = "https://" + raw
        }
        if !raw.hasSuffix("/") { raw += "/" }

        let url = URL(string: raw + "method/users.get?v=5.131&access_token=\(token)&fields=photo_100,city,online,verified,screen_name")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(URLError(.cannotDecodeContentData)))
                return
            }

            struct VKCity: Decodable {
                let id: Int?
                let title: String?

                init(from decoder: Decoder) throws {
                    if let container = try? decoder.container(keyedBy: CodingKeys.self) {
                        id = try? container.decode(Int.self, forKey: .id)
                        title = try? container.decode(String.self, forKey: .title)
                    } else if let stringValue = try? decoder.singleValueContainer().decode(String.self) {
                        id = nil
                        title = stringValue
                    } else {
                        id = nil
                        title = nil
                    }
                }

                enum CodingKeys: String, CodingKey {
                    case id, title
                }
            }

            struct VKUserResponse: Decodable {
                let id: Int
                let first_name: String
                let last_name: String
                let screen_name: String?
                let photo_100: String?
                let city: VKCity?
                let online: Int?
                let verified: Int?
            }

            struct VKResponseWrapper: Decodable {
                let response: [VKUserResponse]?
            }

            do {
                let decoded = try JSONDecoder().decode(VKResponseWrapper.self, from: data)
                if let vkUser = decoded.response?.first {
                    let user = User(
                        uid: vkUser.id,
                        username: vkUser.screen_name ?? "id\(vkUser.id)",
                        displayName: "\(vkUser.first_name) \(vkUser.last_name)".trimmingCharacters(in: .whitespaces),
                        avatarURL: vkUser.photo_100.flatMap { URL(string: $0) },
                        city: vkUser.city?.title,
                        isOnline: vkUser.online == 1,
                        lastSeen: nil,
                        isOfficial: vkUser.verified == 1
                    )
                    completion(.success(user))
                } else {
                    completion(.failure(URLError(.cannotParseResponse)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
