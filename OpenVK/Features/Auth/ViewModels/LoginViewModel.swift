//
//  LoginViewModel.swift
//  OpenVK for iOS
//

import Foundation
import Combine

final class LoginViewModel: ObservableObject {

    @Published var selectedInstanceOption: InstanceOption {
        didSet {
            AppConfig.currentInstanceOption = selectedInstanceOption
        }
    }
    @Published var customInstanceHost: String {
        didSet {
            AppConfig.customInstanceHost = customInstanceHost
        }
    }
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isPasswordVisible: Bool = false
    @Published var showPasswordField: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let auth: AuthService
    var onSuccess: (() -> Void)?

    init(auth: AuthService = .shared, onSuccess: (() -> Void)? = nil) {
        self.auth = auth
        self.onSuccess = onSuccess
        self.selectedInstanceOption = AppConfig.currentInstanceOption
        self.customInstanceHost = AppConfig.customInstanceHost
    }

    var canContinue: Bool {
        if isLoading || email.isEmpty { return false }
        if selectedInstanceOption == .custom && customInstanceHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return true
    }

    func handleContinue() {
        guard canContinue else { return }

        saveInstanceConfig()

        if !showPasswordField {
            showPasswordField = true
            return
        }
        guard !password.isEmpty else { return }

        performSignIn()
    }

    private func saveInstanceConfig() {
        AppConfig.currentInstanceOption = selectedInstanceOption
        AppConfig.customInstanceHost = customInstanceHost
    }

    private func performSignIn() {
        isLoading = true
        errorMessage = nil
        auth.signIn(email: email, password: password) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.onSuccess?()
                }
            case .failure(let error):
                self.errorMessage = error.errorDescription
            }
        }
    }
}
