//
//  LoginView.swift
//  OpenVK for iOS
//

import SwiftUI

struct LoginView: View {

    @StateObject private var viewModel: LoginViewModel
    var onCancel: (() -> Void)?

    init(onSuccess: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: LoginViewModel(onSuccess: onSuccess))
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        LoginHeaderView()
                            .padding(.top, 60)
                            .padding(.bottom, 40)

                        LoginFormView(viewModel: viewModel)
                            .padding(.horizontal, 24)

                        LoginActionsView(viewModel: viewModel)
                            .padding(.horizontal, 24)
                            .padding(.top, 32)

                        Spacer(minLength: 48)

                        LoginFooterView()
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                    }
                }

                if let onCancel = onCancel {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                onCancel()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                                    .opacity(0.8)
                                    .padding()
                            }
                        }
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoginView().preferredColorScheme(.light).previewDisplayName("Light")
            LoginView().preferredColorScheme(.dark).previewDisplayName("Dark")
        }
    }
}
