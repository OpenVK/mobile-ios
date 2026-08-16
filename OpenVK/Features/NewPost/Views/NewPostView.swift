//
//  NewPostView.swift
//  OpenVK for iOS
//

import SwiftUI
import PhotosUI

struct NewPostView: View {

    @Binding var isPresented: Bool
    let ownerID: Int?
    let targetUser: User?
    var onPostCreated: ((Post) -> Void)?
    @StateObject private var viewModel: NewPostViewModel
    @State private var showImagePicker: Bool = false
    @State private var showPostOptions: Bool = false

    init(isPresented: Binding<Bool>, ownerID: Int? = nil, targetUser: User? = nil, onPostCreated: ((Post) -> Void)? = nil) {
        self._isPresented = isPresented
        self.ownerID = ownerID ?? targetUser?.uid
        self.targetUser = targetUser
        self.onPostCreated = onPostCreated
        self._viewModel = StateObject(wrappedValue: NewPostViewModel(ownerID: ownerID, targetUser: targetUser))
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                NewPostAuthorHeader(
                    targetUser: viewModel.targetUser ?? targetUser,
                    isGroup: viewModel.isGroup
                )

                NewPostEditor(text: $viewModel.text)

                if !viewModel.selectedPhotosData.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<viewModel.selectedPhotosData.count, id: \.self) { index in
                                if let uiImage = UIImage(data: viewModel.selectedPhotosData[index]) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .cornerRadius(12)
                                            .clipped()
                                        
                                        Button(action: {
                                            viewModel.selectedPhotosData.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.gray)
                                                .background(Color.white.clipShape(Circle()))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .frame(height: 120)
                    .padding(.bottom, 8)
                }

                Divider()

                NewPostAttachmentsBar(
                    showImagePicker: $showImagePicker,
                    showPostOptions: $showPostOptions
                )

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(L10n.NewPost.cancel) { isPresented = false }
                    .foregroundColor(.appAccent),
                trailing: Button {
                    viewModel.publish { post in
                        onPostCreated?(post)
                        isPresented = false
                    }
                } label: {
                    Text(L10n.NewPost.publish)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(viewModel.canPublish ? .appAccent : Color(.secondaryLabel))
                }
                .disabled(!viewModel.canPublish)
            )
            .sheet(isPresented: $showImagePicker) {
                MultiImagePicker(selectedData: $viewModel.selectedPhotosData)
            }
            .sheet(isPresented: $showPostOptions) {
                postOptionsSheet
            }
            .alert(isPresented: $viewModel.showErrorAlert) {
                Alert(
                    title: Text("Ошибка публикации"),
                    message: Text(viewModel.errorMessage ?? "Не удалось опубликовать запись."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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

private struct NewPostEditor: View {

    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 16))
                .frame(minHeight: 120)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            if text.isEmpty {
                Text(L10n.NewPost.placeholder)
                    .foregroundColor(Color(.placeholderText))
                    .font(.system(size: 16))
                    .padding(.top, 16)
                    .padding(.leading, 18)
                    .allowsHitTesting(false)
            }
        }
        .padding(.top, 8)
    }
}

private struct NewPostAttachmentsBar: View {
    @Binding var showImagePicker: Bool
    @Binding var showPostOptions: Bool

    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                showImagePicker = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "photo").font(.system(size: 17))
                    Text(L10n.NewPost.photo).font(.system(size: 14))
                }
                .foregroundColor(.appAccent)
            }

            Spacer()

            Button(action: {
                showPostOptions = true
                HapticManager.impact(.light)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundColor(.appAccent)
                }
                .padding(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func attachmentButton(icon: String, title: String) -> some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 17))
                Text(title).font(.system(size: 14))
            }
            .foregroundColor(.appAccent)
        }
    }
}

struct MultiImagePicker: UIViewControllerRepresentable {
    @Binding var selectedData: [Data]
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 10
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiImagePicker

        init(_ parent: MultiImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard !results.isEmpty else { return }
            
            let group = DispatchGroup()
            var loadedData: [Int: Data] = [:]
            
            for (index, result) in results.enumerated() {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { [index] (object, error) in
                        if let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.8) {
                            DispatchQueue.main.async {
                                loadedData[index] = data
                            }
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                let sortedData = loadedData.keys.sorted().compactMap { loadedData[$0] }
                self.parent.selectedData.append(contentsOf: sortedData)
            }
        }
    }
}
