//
//  LoginFormView.swift
//  OpenVK for iOS
//

import SwiftUI

struct LoginFormView: View {

    enum FocusableField: Hashable {
        case email
        case password
    }

    @FocusState private var focusedField: FocusableField?
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        VStack(spacing: 0) {
            instanceRow

            if viewModel.selectedInstanceOption == .custom {
                customInstanceRow
                    .transition(.opacity)
            }

            Divider().padding(.leading, 16)

            // Email
            HStack {
                TextField(L10n.Auth.email, text: $viewModel.email)
                    .focused($focusedField, equals: .email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 17))
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                Spacer()
            }

            if viewModel.showPasswordField {
                Divider().padding(.leading, 16)
                passwordRow
                    .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.showPasswordField)
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedInstanceOption)
        .onChange(of: viewModel.showPasswordField) { show in
            if show {
                focusedField = .password
            }
        }
        .onAppear {
            if !viewModel.showPasswordField {
                focusedField = .email
            }
        }
    }

    private var instanceRow: some View {
        HStack {
            Text(L10n.Auth.instance)
                .font(.system(size: 17))
                .foregroundColor(.primary)
                .padding(.leading, 16)

            Spacer()

            Picker(L10n.Auth.instance, selection: $viewModel.selectedInstanceOption) {
                ForEach(InstanceOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.trailing, 8)
        }
        .padding(.vertical, 8)
    }

    private var customInstanceRow: some View {
        VStack(spacing: 0) {
            Divider().padding(.leading, 16)
            HStack {
                TextField(L10n.Auth.customInstancePlaceholder, text: $viewModel.customInstanceHost)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 17))
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                Spacer()
            }
        }
    }

    private var passwordRow: some View {
        HStack {
            Group {
                if viewModel.isPasswordVisible {
                    TextField(L10n.Auth.password, text: $viewModel.password)
                        .focused($focusedField, equals: .password)
                } else {
                    SecureField(L10n.Auth.password, text: $viewModel.password)
                        .focused($focusedField, equals: .password)
                }
            }
            .textContentType(.password)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .font(.system(size: 17))
            .padding(.vertical, 14)
            .padding(.leading, 16)

            Button {
                viewModel.isPasswordVisible.toggle()
            } label: {
                Image(systemName: viewModel.isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.tertiaryLabel))
                    .frame(width: 44, height: 44)
            }
            .padding(.trailing, 4)
        }
    }
}
