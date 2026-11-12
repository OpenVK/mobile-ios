//
//  NewPostView.swift
//  OpenVK for iOS
//

import SwiftUI
import UIKit

struct NewPostView: View {

    @Binding var isPresented: Bool
    let ownerID: Int?
    let targetUser: User?
    var onPostCreated: ((Post) -> Void)?
    @StateObject private var viewModel: NewPostViewModel
    @State private var showImagePicker: Bool = false
    @State private var showPostOptions: Bool = false
    @FocusState private var editorFocused: Bool

    init(isPresented: Binding<Bool>, ownerID: Int? = nil, targetUser: User? = nil, onPostCreated: ((Post) -> Void)? = nil) {
        self._isPresented = isPresented
        self.ownerID = ownerID ?? targetUser?.uid
        self.targetUser = targetUser
        self.onPostCreated = onPostCreated
        self._viewModel = StateObject(wrappedValue: NewPostViewModel(ownerID: ownerID, targetUser: targetUser))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NewPostAuthorHeader(targetUser: viewModel.targetUser ?? targetUser, isGroup: viewModel.isGroup)
                    ZStack(alignment: .topLeading) {
                        if viewModel.text.isEmpty {
                            Text(L10n.NewPost.placeholder)
                                .foregroundColor(Color(.placeholderText))
                                .padding(.horizontal, 5)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $viewModel.text)
                            .font(.body)
                            .frame(minHeight: 220)
                            .focused($editorFocused)
                            .composerEditorBackground()
                    }
                    .padding(.horizontal, 16)
                    composerAttachments
                }
                .padding(.bottom, 20)
            }
            .composerKeyboardDismissal()
            .navigationTitle("Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        editorFocused = false
                        isPresented = false
                    } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Закрыть")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        editorFocused = false
                        viewModel.publish { post in
                            onPostCreated?(post)
                            isPresented = false
                        }
                    } label: {
                        if viewModel.isSubmitting { ProgressView() }
                        else { Label("Опубликовать", systemImage: "arrow.up") }
                    }
                    .disabled(!viewModel.canPublish)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        editorFocused = false
                        showImagePicker = true
                    } label: { Label("Прикрепить", systemImage: "paperclip") }
                    Spacer()
                    Button {
                        editorFocused = false
                        showPostOptions = true
                    } label: {
                        Image(systemName: viewModel.hasActiveOptions ? "slider.horizontal.3" : "ellipsis.circle")
                    }
                    .accessibilityLabel("Настройки записи")
                }
            }
            .background(Color(.systemBackground))
        }
        .navigationViewStyle(.stack)
        .composerPresentation()
        .disabled(viewModel.isSubmitting)
        .interactiveDismissDisabled(viewModel.isSubmitting)
        .sheet(isPresented: $showImagePicker) { AttachmentPicker(selection: $viewModel.attachmentSelection) }
        .sheet(isPresented: $showPostOptions) { postOptionsSheet }
        .alert(isPresented: $viewModel.showErrorAlert) {
            Alert(title: Text("Ошибка публикации"), message: Text(viewModel.errorMessage ?? "Не удалось опубликовать запись."), dismissButton: .default(Text("OK")))
        }
    }

    private var composerAttachments: some View {
        VStack(spacing: 8) {
            if !viewModel.attachmentSelection.selectedPhotosData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.attachmentSelection.selectedPhotosData.indices, id: \.self) { index in
                            if let image = UIImage(data: viewModel.attachmentSelection.selectedPhotosData[index]) {
                                Image(uiImage: image)
                                    .resizable().scaledToFill()
                                    .frame(width: 112, height: 112).clipped()
                                    .cornerRadius(12)
                                    .overlay(alignment: .topTrailing) {
                                        Button { viewModel.attachmentSelection.selectedPhotosData.remove(at: index) } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                                .font(.title3)
                                                .padding(5)
                                        }
                                        .accessibilityLabel("Убрать фотографию")
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            ForEach(viewModel.attachmentSelection.selectedAttachments) { attachment in
                attachmentRow(attachment.title, icon: attachment.icon) {
                    viewModel.attachmentSelection.selectedAttachments.removeAll { $0.id == attachment.id }
                }
            }
            if let poll = viewModel.attachmentSelection.pollDraft {
                attachmentRow(poll.question, icon: "chart.bar.xaxis") { viewModel.attachmentSelection.pollDraft = nil }
            }
            if let place = viewModel.attachmentSelection.selectedPlace {
                attachmentRow(place.name, icon: "mappin.and.ellipse") { viewModel.attachmentSelection.selectedPlace = nil }
            }
            if !viewModel.attachmentSelection.sourceURL.isEmpty {
                attachmentRow(viewModel.attachmentSelection.sourceURL, icon: "link") { viewModel.attachmentSelection.sourceURL = "" }
            }
        }
    }

    private func attachmentRow(_ title: String, icon: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.appAccent).frame(width: 28)
            Text(title).lineLimit(2)
            Spacer()
            Button(action: remove) { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                .accessibilityLabel("Убрать вложение")
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private var postOptionsSheet: some View {
        NavigationView {
            List {
                if viewModel.isGroup && viewModel.canPostAsGroup {
                    Section(
                        header: Text("Сообщество"),
                        footer: Text(viewModel.fromGroup ? "Запись будет опубликована от имени сообщества" : "Запись будет опубликована от вашего имени")
                    ) {
                        Toggle(isOn: $viewModel.fromGroup.animation()) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.appAccent)
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                Text("От имени сообщества")
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .appAccent))
                        .onChange(of: viewModel.fromGroup) { newValue in
                            if !newValue {
                                viewModel.signed = false
                            }
                        }
                        
                        Toggle(isOn: $viewModel.signed) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.orange)
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "signature")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                Text("Подпись автора")
                                    .font(.system(size: 15))
                                    .foregroundColor(viewModel.fromGroup ? .primary : Color(.secondaryLabel))
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .appAccent))
                        .disabled(!viewModel.fromGroup)
                        .opacity(viewModel.fromGroup ? 1.0 : 0.5)
                    }
                }
                
                Section(header: Text("Отображение")) {
                    Toggle(isOn: $viewModel.isExplicit) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.red)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Скрыть под спойлер")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .appAccent))
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Опции публикации")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        showPostOptions = false
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appAccent)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct NewPostAuthorHeader: View {
    @ObservedObject var auth = AuthService.shared
    let targetUser: User?
    let isGroup: Bool

    private var currentUser: User {
        auth.currentUser ?? .current
    }

    var body: some View {
        HStack(spacing: 12) {
            if isGroup, let group = targetUser {
                ZStack(alignment: .bottomTrailing) {
                    Avatar(user: group, size: 44)
                    
                    Avatar(user: currentUser, size: 18)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .offset(x: 3, y: 3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(group.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        
                        if group.isOfficial == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.appAccent)
                        }
                        SupporterBadgeView(screenName: group.username)
                    }
                    
                    Text("от \(currentUser.displayName)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(.secondaryLabel))
                        .lineLimit(1)
                }
            } else {
                Avatar(user: currentUser, size: 42)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(currentUser.displayName)
                            .font(.system(size: 15, weight: .semibold))
                        
                        if currentUser.isOfficial == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.appAccent)
                        }
                        SupporterBadgeView(screenName: currentUser.username)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

private extension View {
    @ViewBuilder
    func composerPresentation() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.large]).presentationDragIndicator(.visible)
        } else { self }
    }

    @ViewBuilder
    func composerEditorBackground() -> some View {
        if #available(iOS 16.0, *) { self.scrollContentBackground(.hidden) }
        else { self }
    }

    @ViewBuilder
    func composerKeyboardDismissal() -> some View {
        if #available(iOS 16.0, *) { self.scrollDismissesKeyboard(.interactively) }
        else { self }
    }
}
