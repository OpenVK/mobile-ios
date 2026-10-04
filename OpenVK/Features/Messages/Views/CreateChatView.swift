//
//  CreateChatView.swift
//  OpenVK for iOS
//

import SwiftUI
import PhotosUI
import UIKit

struct CreateChatView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel = CreateChatViewModel()
    @State private var query = ""
    @State private var showConversationCreation = false
    @State private var selectedUser: User?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoadingFriends {
                    ProgressView("Загрузка друзей…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.friends.isEmpty {
                    VStack(spacing: 12) {
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Повторить") {
                            viewModel.loadFriends()
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    results
                }
            }
            .navigationTitle("Написать сообщение")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Поиск..."
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityLabel("Закрыть")
                }
            }
            .background(
                NavigationLink(
                    destination: ConversationParticipantsView(
                        viewModel: viewModel,
                        onCreatedChatClosed: { presentationMode.wrappedValue.dismiss() }
                    ),
                    isActive: $showConversationCreation
                ) {
                    EmptyView()
                }
                .hidden()
            )
        }
        .navigationViewStyle(.stack)
        .onAppear {
            viewModel.loadFriends()
        }
        .onChange(of: query) { newValue in
            viewModel.searchGlobal(query: newValue)
        }
        .fullScreenCover(item: $selectedUser) { user in
            ChatFullScreenView(conversation: directConversation(with: user))
        }
    }

    @ViewBuilder
    private var results: some View {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            friendList
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    createConversationButton
                    resultSection(title: "Друзья", users: viewModel.filteredFriends(for: query))
                    resultSection(title: "Поиск по OpenVK", users: viewModel.globalUsers)

                    if viewModel.isLoadingGlobal {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
        }
    }

    private var friendList: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                List {
                    createConversationButton
                        .listRowInsets(EdgeInsets())

                    ForEach(viewModel.groupedFriends, id: \.0) { letter, group in
                        Section {
                            ForEach(group) {
                                userRow($0)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.visible)
                            }
                        } header: {
                            Text(letter)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.appAccent)
                                .id(letter)
                        }
                    }
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 16)
                }

                alphabetIndex(proxy: proxy)
                    .padding(.trailing, 4)
            }
        }
    }

    private var createConversationButton: some View {
        Button {
            showConversationCreation = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.appAccent)
                    .frame(width: 28)
                Text("Создать беседу")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func resultSection(title: String, users: [User]) -> some View {
        Group {
            if !users.isEmpty {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ForEach(users) { user in
                    userRow(user)
                        .onAppear {
                            viewModel.loadMoreGlobalIfNeeded(after: user, query: query)
                        }
                }
            }
        }
    }

    private func userRow(_ user: User) -> some View {
        Button {
            selectedUser = user
        } label: {
            HStack(spacing: 12) {
                Avatar(user: user, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName == "DELETED" ? "Удалённый аккаунт" : user.displayName)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    if user.deactivated != "deleted" {
                        Text("@\(user.username)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func directConversation(with user: User) -> Conversation {
        Conversation(
            id: user.uid ?? 0,
            peer: user,
            lastMessage: "",
            lastMessageAuthorName: nil,
            lastMessageOutgoing: false,
            updatedAt: Date(),
            unreadCount: 0,
            lastMessageId: 0,
            lastMessageReadState: nil,
            isChat: false
        )
    }

    private func alphabetIndex(proxy: ScrollViewProxy) -> some View {
        let letters = viewModel.groupedFriends.map(\.0)

        return GeometryReader { geometry in
            let availableHeight = max(0, geometry.size.height - 20)
            let itemHeight = max(
                8,
                min(16, (availableHeight - 10) / CGFloat(max(letters.count, 1)))
            )
            let indexHeight = CGFloat(letters.count) * itemHeight + 10
            let topInset = max(0, (geometry.size.height - indexHeight) / 2)

            VStack(spacing: 0) {
                ForEach(letters, id: \.self) { letter in
                    Button(letter) {
                        scrollToLetter(letter, using: proxy)
                    }
                    .font(.system(size: min(10, itemHeight * 0.7), weight: .semibold))
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.appAccent)
                    .frame(width: 26, height: itemHeight)
                }
            }
            .padding(.vertical, 5)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .frame(width: 32, height: indexHeight)
            .position(x: geometry.size.width - 20, y: topInset + indexHeight / 2)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !letters.isEmpty else { return }
                        let contentY = value.location.y - topInset - 5
                        let index = min(
                            max(Int(contentY / itemHeight), 0),
                            letters.count - 1
                        )
                        scrollToLetter(letters[index], using: proxy)
                    }
            )
        }
        .frame(width: 40)
    }

    private func scrollToLetter(_ letter: String, using proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.12)) {
            proxy.scrollTo(letter, anchor: .top)
        }
    }
}

private struct ConversationParticipantsView: View {
    @ObservedObject var viewModel: CreateChatViewModel
    let onCreatedChatClosed: () -> Void
    @State private var selectedUserIDs = Set<Int>()

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                List {
                    ForEach(viewModel.groupedFriends, id: \.0) { letter, users in
                        Section {
                            ForEach(users) { user in
                                participantRow(user)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.visible)
                            }
                        } header: {
                            Text(letter)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.appAccent)
                                .id(letter)
                        }
                    }
                }
                .listStyle(.plain)

                participantAlphabetIndex(proxy: proxy)
                    .padding(.trailing, 4)
            }
        }
        .navigationTitle("Участники: \(selectedUserIDs.count + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    ConversationSetupView(
                        viewModel: viewModel,
                        memberIDs: Array(selectedUserIDs),
                        onCreatedChatClosed: onCreatedChatClosed
                    )
                } label: {
                    Text("Далее")
                }
            }
        }
    }

    private func participantRow(_ user: User) -> some View {
        Button {
            if let userID = user.uid { toggle(userID) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected(user) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected(user) ? Color.appAccent : .secondary)
                Avatar(user: user, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName == "DELETED" ? "Удалённый аккаунт" : user.displayName)
                        .foregroundStyle(.primary)
                    if user.deactivated != "deleted" {
                        Text("@\(user.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func isSelected(_ user: User) -> Bool {
        user.uid.map(selectedUserIDs.contains) ?? false
    }

    private func participantAlphabetIndex(proxy: ScrollViewProxy) -> some View {
        let letters = viewModel.groupedFriends.map(\.0)
        return GeometryReader { geometry in
            let availableHeight = max(0, geometry.size.height - 20)
            let itemHeight = max(8, min(16, (availableHeight - 10) / CGFloat(max(letters.count, 1))))
            let indexHeight = CGFloat(letters.count) * itemHeight + 10
            let topInset = max(0, (geometry.size.height - indexHeight) / 2)

            VStack(spacing: 0) {
                ForEach(letters, id: \.self) { letter in
                    Button(letter) {
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(letter, anchor: .top)
                        }
                    }
                    .font(.system(size: min(10, itemHeight * 0.7), weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 26, height: itemHeight)
                }
            }
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
            .frame(width: 32, height: indexHeight)
            .position(x: geometry.size.width - 20, y: topInset + indexHeight / 2)
        }
        .frame(width: 40)
    }

    private func toggle(_ userID: Int) {
        if selectedUserIDs.contains(userID) {
            selectedUserIDs.remove(userID)
        } else {
            selectedUserIDs.insert(userID)
        }
    }
}

private struct ConversationSetupView: View {
    @ObservedObject var viewModel: CreateChatViewModel
    let memberIDs: [Int]
    let onCreatedChatClosed: () -> Void
    @State private var title = ""
    @State private var isAvatarPickerPresented = false
    @State private var isAvatarCropperPresented = false
    @State private var selectedAvatarImage: UIImage?
    @State private var avatarData: Data?
    @State private var isCreating = false
    @State private var createdConversation: Conversation?
    @State private var errorMessage: String?

    var body: some View {
        configuredForm
            .overlay {
                if isCreating {
                    ProgressView("Создаём беседу…")
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .sheet(isPresented: $isAvatarPickerPresented) {
                ChatAvatarPicker(selectedImage: $selectedAvatarImage)
            }
            .onChange(of: selectedAvatarImage) { image in
                isAvatarCropperPresented = image != nil
            }
            .fullScreenCover(isPresented: $isAvatarCropperPresented) {
                cropper
            }
            .alert("Не удалось создать беседу", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Попробуйте ещё раз")
            }
            .fullScreenCover(item: $createdConversation) { conversation in
                ChatFullScreenView(conversation: conversation, onClose: onCreatedChatClosed)
            }
    }

    private var configuredForm: some View {
        setupForm
            .navigationTitle("Новая беседа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Создать", action: createConversation)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
    }

    private var setupForm: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Button { isAvatarPickerPresented = true } label: { avatarPreview }
                        .buttonStyle(.plain)

                    TextField("Название беседы", text: $title)
                        .textInputAutocapitalization(.sentences)
                }
            }
        }
    }

    @ViewBuilder
    private var cropper: some View {
        if let selectedAvatarImage {
            SquareAvatarCropper(image: selectedAvatarImage) { image in
                avatarData = image.jpegData(compressionQuality: 0.86)
                self.selectedAvatarImage = nil
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let avatarData, let image = UIImage(data: avatarData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
        } else {
            Image(systemName: "camera.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.appAccent)
                .frame(width: 56, height: 56)
                .background(Color(.secondarySystemBackground), in: Circle())
                .overlay(Circle().stroke(Color.appAccent.opacity(0.45), lineWidth: 1))
        }
    }

    private func createConversation() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        isCreating = true
        viewModel.createConversation(
            title: trimmedTitle,
            memberIDs: memberIDs,
            avatarData: avatarData
        ) { result in
            isCreating = false
            switch result {
            case .success(let conversation):
                createdConversation = conversation
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ChatAvatarPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ChatAvatarPicker

        init(parent: ChatAvatarPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                parent.presentationMode.wrappedValue.dismiss()
                return
            }

            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    self.parent.selectedImage = object as? UIImage
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

private struct SquareAvatarCropper: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let onComplete: (UIImage) -> Void
    @State private var scale: CGFloat = 1
    @State private var scaleAtGestureStart: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var offsetAtGestureStart = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width - 32, geometry.size.height - 180)
            let baseScale = max(side / image.size.width, side / image.size.height)

            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .frame(width: image.size.width, height: image.size.height)
                    .scaleEffect(baseScale * scale)
                    .offset(clampedOffset(for: side, baseScale: baseScale))
                    .frame(width: side, height: side)
                    .clipped()
                    .overlay(Rectangle().stroke(.white.opacity(0.9), lineWidth: 1))
                    .gesture(magnificationGesture(side: side, baseScale: baseScale))
                    .simultaneousGesture(dragGesture(side: side, baseScale: baseScale))

                VStack {
                    HStack {
                        Button("Отмена") { dismiss() }
                        Spacer()
                        Button("Готово") {
                            if let croppedImage = croppedImage(side: side, baseScale: baseScale) {
                                onComplete(croppedImage)
                            }
                            dismiss()
                        }
                        .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                    Spacer()
                    Text("Переместите и увеличьте фотографию")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 36)
                }
            }
        }
    }

    private func magnificationGesture(side: CGFloat, baseScale: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(scaleAtGestureStart * value, 1), 4)
                offset = clampedOffset(for: side, baseScale: baseScale)
            }
            .onEnded { _ in
                scaleAtGestureStart = scale
                offsetAtGestureStart = offset
            }
    }

    private func dragGesture(side: CGFloat, baseScale: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: offsetAtGestureStart.width + value.translation.width,
                    height: offsetAtGestureStart.height + value.translation.height
                )
                offset = clampedOffset(for: side, baseScale: baseScale)
            }
            .onEnded { _ in
                offsetAtGestureStart = offset
            }
    }

    private func clampedOffset(for side: CGFloat, baseScale: CGFloat) -> CGSize {
        let displayedWidth = image.size.width * baseScale * scale
        let displayedHeight = image.size.height * baseScale * scale
        let maxX = max(0, (displayedWidth - side) / 2)
        let maxY = max(0, (displayedHeight - side) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func croppedImage(side: CGFloat, baseScale: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let displayScale = baseScale * scale
        let cropSide = side / displayScale
        let originX = (image.size.width - cropSide) / 2 - offset.width / displayScale
        let originY = (image.size.height - cropSide) / 2 - offset.height / displayScale
        let pointToPixelX = CGFloat(cgImage.width) / image.size.width
        let pointToPixelY = CGFloat(cgImage.height) / image.size.height
        let cropRect = CGRect(
            x: originX * pointToPixelX,
            y: originY * pointToPixelY,
            width: cropSide * pointToPixelX,
            height: cropSide * pointToPixelY
        ).integral

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped)
    }
}

private struct ChatFullScreenView: View {
    @Environment(\.dismiss) private var dismiss
    let conversation: Conversation
    var onClose: (() -> Void)?

    var body: some View {
        NavigationView {
            ChatView(conversation: conversation)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                            if let onClose {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: onClose)
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .accessibilityLabel("Закрыть чат")
                    }
                }
        }
        .navigationViewStyle(.stack)
    }
}
