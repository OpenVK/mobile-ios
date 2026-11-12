//
//  AttachmentPicker.swift
//  OpenVK for iOS
//
//

import SwiftUI
import Photos
import AVFoundation
import UIKit
import MapKit
import PencilKit

enum AttachmentPickerCategory: String, CaseIterable, Identifiable {
    case gallery, videos, audio, documents, openVKPhotos, notes, graffiti, poll, place, source

    var id: String { rawValue }
    var title: String {
        switch self {
        case .gallery: return "Галерея"
        case .videos: return "Видео"
        case .audio: return "Аудио"
        case .documents: return "Документы"
        case .openVKPhotos: return "Фото OpenVK"
        case .notes: return "Заметки"
        case .graffiti: return "Граффити"
        case .poll: return "Опрос"
        case .place: return "Место"
        case .source: return "Источник"
        }
    }
    var icon: String {
        switch self {
        case .gallery: return "photo.on.rectangle"
        case .videos: return "video.fill"
        case .audio: return "music.note"
        case .documents: return "doc.fill"
        case .openVKPhotos: return "photo.stack"
        case .notes: return "note.text"
        case .graffiti: return "scribble.variable"
        case .poll: return "chart.bar.xaxis"
        case .place: return "mappin.and.ellipse"
        case .source: return "link"
        }
    }
    var color: Color {
        switch self {
        case .gallery, .notes: return .purple
        case .documents, .openVKPhotos, .source: return .blue
        case .videos, .graffiti: return .pink
        case .audio, .poll: return .orange
        case .place: return .green
        }
    }
    var method: String {
        switch self {
        case .documents: return "docs.get"
        case .videos: return "video.get"
        case .audio: return "audio.get"
        case .openVKPhotos: return "photos.getAll"
        case .notes: return "notes.get"
        default: return ""
        }
    }
    var attachmentPrefix: String {
        switch self {
        case .documents: return "doc"
        case .videos: return "video"
        case .audio: return "audio"
        case .notes: return "note"
        default: return "photo"
        }
    }
}

struct AttachmentPicker: View {
    @Binding var selection: AttachmentPickerSelection
    private let categories: [AttachmentPickerCategory]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gallery = PickerGallerySelection()
    @State private var showCamera = false
    @State private var galleryError: String?
    @State private var isImporting = false
    @State private var category: AttachmentPickerCategory = .gallery
    @State private var items: [PickerAttachment] = []
    @State private var isLoading = false
    @State private var hasMore = false
    @State private var offset = 0
    @State private var errorMessage: String?

    init(selection: Binding<AttachmentPickerSelection>, categories: [AttachmentPickerCategory] = AttachmentPickerCategory.allCases) {
        self._selection = selection
        let enabled = categories.isEmpty ? AttachmentPickerCategory.allCases : categories
        self.categories = enabled.reduce(into: []) { result, category in
            if !result.contains(category) { result.append(category) }
        }
        self._category = State(initialValue: enabled[0])
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Group {
                    switch category {
                    case .gallery:
                        PickerGalleryGrid(selection: gallery, availableSlots: selection.remainingAttachmentSlots, openCamera: openCamera)
                    case .graffiti:
                        PickerGraffitiEditor(selection: $selection, reservedSlots: gallery.selected.count)
                    case .poll:
                        PickerPollEditor(selection: $selection, reservedSlots: gallery.selected.count)
                    case .place:
                        PickerPlaceEditor(selection: $selection)
                    case .source:
                        PickerSourceEditor(selection: $selection)
                    default:
                        libraryContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { categoryBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Закрыть")
                }
                ToolbarItem(placement: .principal) {
                    if category == .gallery {
                        Menu {
                            Button { gallery.selectAlbum(nil) } label: {
                                if gallery.selectedAlbumID == nil {
                                    Label("Все фотографии", systemImage: "checkmark")
                                } else { Text("Все фотографии") }
                            }
                            ForEach(gallery.albums, id: \.localIdentifier) { album in
                                Button { gallery.selectAlbum(album.localIdentifier) } label: {
                                    if gallery.selectedAlbumID == album.localIdentifier {
                                        Label(album.localizedTitle ?? "Альбом", systemImage: "checkmark")
                                    } else { Text(album.localizedTitle ?? "Альбом") }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(gallery.albumTitle).font(.headline).lineLimit(1)
                                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                            }
                            .foregroundColor(.primary)
                        }
                        .accessibilityLabel("Выбрать альбом: \(gallery.albumTitle)")
                    } else {
                        Text(category.title).font(.headline)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if selection.hasAttachments || !gallery.selected.isEmpty {
                        Button("Готово") { importSelection() }
                    }
                }
            }
            .task(id: category) {
                items = []
                offset = 0
                hasMore = false
                errorMessage = nil
                if !category.method.isEmpty { await load(reset: true) }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            if !categories.contains(category), let first = categories.first { category = first }
        }
        .background(Color(.systemBackground))
        .attachmentPanelDetents()
        .disabled(isImporting)
        .interactiveDismissDisabled(isImporting)
        .overlay {
            if isImporting {
                ProgressView("Подготовка фотографий…")
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showCamera) {
            PickerCamera { image in
                if let data = image.jpegData(compressionQuality: 0.8),
                   selection.remainingAttachmentSlots > gallery.selected.count {
                    selection.selectedPhotosData.append(data)
                }
            }
        }
        .alert("Галерея", isPresented: Binding(
            get: { galleryError != nil },
            set: { if !$0 { galleryError = nil } }
        )) {
            Button("OK", role: .cancel) { galleryError = nil }
        } message: { Text(galleryError ?? "") }
    }

    private var categoryBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(categories) { item in
                        Button {
                            category = item
                            withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(item.id, anchor: .center) }
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: item.icon).font(.system(size: 21))
                                Text(item.title).font(.system(size: 11, weight: category == item ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .foregroundColor(category == item ? .appAccent : .secondary)
                            .frame(minWidth: 76, minHeight: 58)
                            .padding(.horizontal, 5)
                            .background(category == item ? Color.appAccent.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(category == item ? .isSelected : [])
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.bar)
        }
    }

    private func openCamera() {
        guard selection.remainingAttachmentSlots > gallery.selected.count else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            galleryError = "Камера недоступна на этом устройстве."
            return
        }
        AVCaptureDevice.requestAccess(for: .video) { allowed in
            DispatchQueue.main.async {
                if allowed { showCamera = true }
                else { galleryError = "Разрешите доступ к камере в настройках приложения." }
            }
        }
    }

    private func importSelection() {
        guard !isImporting else { return }
        guard !gallery.selected.isEmpty else { dismiss(); return }
        isImporting = true
        Task { @MainActor in
            let assets = gallery.selected
            var failed = false
            for asset in assets {
                if let data = await gallery.imageData(for: asset), selection.remainingAttachmentSlots > 0 {
                    selection.selectedPhotosData.append(data)
                    gallery.selected.removeAll { $0.localIdentifier == asset.localIdentifier }
                } else { failed = true }
            }
            isImporting = false
            if failed { galleryError = "Некоторые фотографии не удалось загрузить. Проверьте подключение к iCloud и повторите попытку." }
            else { dismiss() }
        }
    }

    private var libraryContent: some View {
        List {
            Section {
                ForEach(items) { item in
                    let selected = selection.selectedAttachments.contains { $0.id == item.id }
                    Button {
                        if selected {
                            selection.selectedAttachments.removeAll { $0.id == item.id }
                        } else if selection.remainingAttachmentSlots > gallery.selected.count {
                            selection.selectedAttachments.append(item)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.system(size: 22))
                                .foregroundColor(category.color)
                                .frame(width: 36, height: 40)
                            Text(item.title)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selected ? .appAccent : Color(.tertiaryLabel))
                        }
                        .contentShape(Rectangle())
                    }
                    .disabled(!selected && selection.remainingAttachmentSlots <= gallery.selected.count)
                    .accessibilityValue(selected ? "Выбрано" : "Не выбрано")
                }
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.secondary)
                    Button("Повторить") { Task { await load(reset: items.isEmpty) } }
                } else if items.isEmpty {
                    Text("В вашей коллекции пока нет вложений этого типа.")
                        .foregroundColor(.secondary)
                } else if hasMore {
                    Button("Загрузить ещё") { Task { await load(reset: false) } }
                }
            } header: {
                Text("Ваша коллекция OpenVK")
            } footer: {
                Text("Выбрано \(selection.attachmentCount + gallery.selected.count) из \(selection.maximumAttachments)")
            }
        }
        .listStyle(.plain)
    }

    @MainActor
    private func load(reset: Bool) async {
        let requestedCategory = category
        isLoading = true
        errorMessage = nil
        defer { if category == requestedCategory { isLoading = false } }
        do {
            var parameters = ["count": "30", "offset": "\(reset ? 0 : offset)"]
            if requestedCategory == .notes { parameters["user_id"] = "\(AuthService.shared.currentUser?.uid ?? 0)" }
            if requestedCategory == .openVKPhotos { parameters["owner_id"] = "\(AuthService.shared.currentUser?.uid ?? 0)" }
            let response = try await APIClient.shared.call(
                method: requestedCategory.method,
                parameters: parameters,
                as: AttachmentLibraryResponse.self
            )
            try Task.checkCancellation()
            guard category == requestedCategory else { return }
            let loaded = response.items.compactMap { item -> PickerAttachment? in
                guard let id = item.id, let owner = item.ownerId ?? item.userId else { return nil }
                let title = [item.artist, item.title ?? item.text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
                return PickerAttachment(
                    id: "\(requestedCategory.attachmentPrefix)\(owner)_\(id)",
                    title: title.isEmpty ? requestedCategory.title : title,
                    icon: requestedCategory.icon
                )
            }
            if reset { items = [] }
            for item in loaded where !items.contains(where: { $0.id == item.id }) { items.append(item) }
            offset = (reset ? 0 : offset) + response.items.count
            hasMore = !response.items.isEmpty && offset < response.count
        } catch is CancellationError {
        } catch {
            guard category == requestedCategory else { return }
            errorMessage = error.localizedDescription
        }
    }
}

private struct AttachmentLibraryResponse: Decodable {
    let count: Int
    let items: [Item]

    struct Item: Decodable {
        let id: Int?
        let ownerId: Int?
        let userId: Int?
        let title: String?
        let text: String?
        let artist: String?
    }
}

private extension View {
    @ViewBuilder
    func attachmentPanelDetents() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .opaqueAttachmentBackground()
        } else {
            self
        }
    }
}

private extension View {
    @ViewBuilder
    func opaqueAttachmentBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(Color(.systemBackground))
        } else { self }
    }
}

@MainActor
private final class PickerGallerySelection: ObservableObject {
    @Published var assets: [PHAsset] = []
    @Published var albums: [PHAssetCollection] = []
    @Published var selectedAlbumID: String?
    @Published var selected: [PHAsset] = []
    @Published var authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var isLoading = true
    let manager = PHCachingImageManager()

    var albumTitle: String {
        albums.first { $0.localIdentifier == selectedAlbumID }?.localizedTitle ?? "Все фотографии"
    }

    func load() async {
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard authorization == .authorized || authorization == .limited else {
            assets = []
            albums = []
            isLoading = false
            return
        }
        var collections: [PHAssetCollection] = []
        let photoOptions = PHFetchOptions()
        photoOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        for type in [PHAssetCollectionType.smartAlbum, .album] {
            PHAssetCollection.fetchAssetCollections(with: type, subtype: .any, options: nil).enumerateObjects { album, _, _ in
                guard album.assetCollectionSubtype != .smartAlbumAllHidden,
                      PHAsset.fetchAssets(in: album, options: photoOptions).count > 0,
                      !collections.contains(where: { $0.localIdentifier == album.localIdentifier }) else { return }
                collections.append(album)
            }
        }
        albums = collections
        if let id = selectedAlbumID, !albums.contains(where: { $0.localIdentifier == id }) {
            selectedAlbumID = nil
        }
        selectAlbum(selectedAlbumID)
        isLoading = false
    }

    func selectAlbum(_ id: String?) {
        selectedAlbumID = id
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let result: PHFetchResult<PHAsset>
        if let album = albums.first(where: { $0.localIdentifier == id }) {
            result = PHAsset.fetchAssets(in: album, options: options)
        } else {
            result = PHAsset.fetchAssets(with: .image, options: options)
        }
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in fetched.append(asset) }
        assets = fetched
    }

    func toggle(_ asset: PHAsset, availableSlots: Int) {
        if selected.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
            selected.removeAll { $0.localIdentifier == asset.localIdentifier }
        } else if selected.count < availableSlots {
            selected.append(asset)
        }
    }

    func imageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            manager.requestImage(for: asset, targetSize: CGSize(width: 2560, height: 2560), contentMode: .aspectFit, options: options) { image, info in
                guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
                continuation.resume(returning: image?.jpegData(compressionQuality: 0.85))
            }
        }
    }
}

private struct PickerGalleryGrid: View {
    @ObservedObject var selection: PickerGallerySelection
    @Environment(\.scenePhase) private var scenePhase
    let availableSlots: Int
    let openCamera: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let side = max(0, (geometry.size.width - 4) / 3)
            ScrollView {
                VStack(spacing: 2) {
                    if selection.authorization == .denied || selection.authorization == .restricted {
                        VStack(spacing: 12) {
                            Text("Разрешите доступ к фотографиям в настройках приложения.")
                                .multilineTextAlignment(.center)
                            Button("Открыть настройки") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                        }
                        .padding(24)
                    }
                    if selection.authorization == .limited {
                        VStack(spacing: 6) {
                            Text("Показаны фотографии, к которым вы разрешили доступ.")
                                .foregroundColor(.secondary)
                            Button("Изменить доступ") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                        }
                        .font(.footnote)
                        .padding(12)
                    }
                    HStack(alignment: .top, spacing: 2) {
                        Button(action: openCamera) {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill").font(.system(size: 34))
                                Text("Камера").font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(width: side, height: side * 2 + 2)
                            .background(Color(white: 0.16))
                        }
                        .buttonStyle(.plain)
                        .disabled(selection.selected.count >= availableSlots)
                        VStack(spacing: 2) {
                            HStack(spacing: 2) {
                                tile(at: 0, side: side)
                                tile(at: 1, side: side)
                            }
                            HStack(spacing: 2) {
                                tile(at: 2, side: side)
                                tile(at: 3, side: side)
                            }
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                        ForEach(Array(selection.assets.dropFirst(4)), id: \.localIdentifier) { asset in
                            assetTile(asset, side: side)
                        }
                    }
                    if selection.isLoading { ProgressView().padding() }
                    else if selection.assets.isEmpty && selection.authorization != .denied && selection.authorization != .restricted {
                        Text("В галерее пока нет фотографий")
                            .foregroundColor(.secondary).padding()
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .task { await selection.load() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await selection.load() } }
        }
    }

    @ViewBuilder
    private func tile(at index: Int, side: CGFloat) -> some View {
        if selection.assets.indices.contains(index) {
            assetTile(selection.assets[index], side: side)
        } else {
            Color(.secondarySystemBackground).frame(width: side, height: side)
        }
    }

    private func assetTile(_ asset: PHAsset, side: CGFloat) -> some View {
        let number = selection.selected.firstIndex { $0.localIdentifier == asset.localIdentifier }.map { $0 + 1 }
        return Button {
            selection.toggle(asset, availableSlots: availableSlots)
        } label: {
            PickerGalleryThumbnail(asset: asset, manager: selection.manager, side: side)
                .overlay(Color.black.opacity(number == nil ? 0 : 0.2))
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Circle().fill(number == nil ? Color.black.opacity(0.2) : Color.appAccent)
                        Circle().strokeBorder(Color.white, lineWidth: 2)
                        if let number = number {
                            Text("\(number)").font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                        }
                    }
                    .frame(width: 25, height: 25)
                    .padding(7)
                }
        }
        .buttonStyle(.plain)
        .disabled(number == nil && selection.selected.count >= availableSlots)
        .accessibilityLabel("Фотография")
        .accessibilityValue(number.map { "Выбрано, \($0)" } ?? "Не выбрано")
    }
}

private struct PickerGalleryThumbnail: View {
    let asset: PHAsset
    let manager: PHImageManager
    let side: CGFloat
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let image = image {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .onAppear {
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            requestID = manager.requestImage(for: asset, targetSize: CGSize(width: side * 2, height: side * 2), contentMode: .aspectFill, options: options) { result, _ in
                DispatchQueue.main.async { image = result }
            }
        }
        .onDisappear {
            if let requestID = requestID { manager.cancelImageRequest(requestID) }
        }
    }
}

private struct PickerCamera: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PickerCamera
        init(_ parent: PickerCamera) { self.parent = parent }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }
    }
}

private struct PickerSourceEditor: View {
    @Binding var selection: AttachmentPickerSelection
    @State private var address = ""

    private var validURL: URL? {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    var body: some View {
        Form {
            Section(header: Text("Ссылка на источник"), footer: Text("Источник будет указан под записью.")) {
                TextField("https://example.com", text: $address)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(selection.sourceURL.isEmpty ? "Прикрепить источник" : "Сохранить источник") {
                    if let url = validURL { selection.sourceURL = url.absoluteString }
                }
                .disabled(validURL == nil)
                if !selection.sourceURL.isEmpty {
                    Label("Источник прикреплён", systemImage: "checkmark.circle.fill").foregroundColor(.secondary)
                    Button("Убрать источник", role: .destructive) { selection.sourceURL = ""; address = "" }
                }
            }
        }
        .onAppear { address = selection.sourceURL }
    }
}

private struct PickerPollEditor: View {
    @Binding var selection: AttachmentPickerSelection
    let reservedSlots: Int
    @State private var question = ""
    @State private var answers = ["", ""]
    @State private var anonymous = false
    @State private var multiple = false

    private var cleanAnswers: [String] { answers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
    private var canAttach: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && cleanAnswers.count >= 2 &&
        Set(cleanAnswers).count == cleanAnswers.count && (selection.pollDraft != nil || selection.remainingAttachmentSlots > reservedSlots)
    }

    var body: some View {
        Form {
            Section(header: Text("Вопрос")) { TextField("О чём спросить?", text: $question) }
            Section(header: Text("Варианты ответа")) {
                ForEach(answers.indices, id: \.self) { index in
                    HStack {
                        TextField("Вариант \(index + 1)", text: $answers[index])
                        if answers.count > 2 {
                            Button { answers.remove(at: index) } label: { Image(systemName: "minus.circle.fill").foregroundColor(.red) }
                                .buttonStyle(.borderless).accessibilityLabel("Удалить вариант")
                        }
                    }
                }
                if answers.count < 10 { Button("Добавить вариант") { answers.append("") } }
            }
            Section {
                Toggle("Анонимный опрос", isOn: $anonymous)
                Toggle("Несколько ответов", isOn: $multiple)
            }
            Section {
                Button(selection.pollDraft == nil ? "Прикрепить опрос" : "Сохранить опрос") {
                    selection.pollDraft = AttachmentPollDraft(question: question.trimmingCharacters(in: .whitespacesAndNewlines), answers: cleanAnswers, anonymous: anonymous, multiple: multiple)
                }
                .disabled(!canAttach)
                if selection.pollDraft != nil {
                    Label("Опрос прикреплён", systemImage: "checkmark.circle.fill").foregroundColor(.secondary)
                    Button("Убрать опрос", role: .destructive) { selection.pollDraft = nil }
                }
            }
        }
        .onAppear {
            if let draft = selection.pollDraft {
                question = draft.question; answers = draft.answers; anonymous = draft.anonymous; multiple = draft.multiple
            }
        }
    }
}

private struct PickerPlaceEditor: View {
    @Binding var selection: AttachmentPickerSelection
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var error: String?

    var body: some View {
        List {
            Section(header: Text("Поиск места")) {
                TextField("Город, адрес или название", text: $query).submitLabel(.search).onSubmit { search() }
                Button("Найти") { search() }.disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                if isSearching { ProgressView() }
                if let error = error { Text(error).foregroundColor(.secondary) }
            }
            if let place = selection.selectedPlace {
                Section(header: Text("Прикреплённое место")) {
                    Label(place.name, systemImage: "mappin.and.ellipse")
                    Button("Убрать место", role: .destructive) { selection.selectedPlace = nil }
                }
            }
            ForEach(results.indices, id: \.self) { index in
                let item = results[index]
                Button {
                    selection.selectedPlace = AttachmentPlace(name: item.name ?? item.placemark.title ?? "Место", latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Место").foregroundColor(.primary)
                        Text(item.placemark.title ?? "").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func search() {
        guard !isSearching, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearching = true; error = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        MKLocalSearch(request: request).start { response, searchError in
            DispatchQueue.main.async {
                isSearching = false
                results = response?.mapItems ?? []
                if let searchError = searchError { error = searchError.localizedDescription }
                else if results.isEmpty { error = "Ничего не найдено. Попробуйте уточнить адрес." }
            }
        }
    }
}

private struct PickerGraffitiEditor: View {
    @Binding var selection: AttachmentPickerSelection
    let reservedSlots: Int
    @State private var canvas = PKCanvasView()
    @State private var hasDrawing = false
    @State private var color: Color = .black
    @State private var erasing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ColorPicker("Цвет", selection: $color, supportsOpacity: false).labelsHidden()
                Button { erasing.toggle() } label: { Image(systemName: erasing ? "pencil" : "eraser") }
                    .accessibilityLabel(erasing ? "Карандаш" : "Ластик")
                Spacer()
                Button("Очистить") { canvas.drawing = PKDrawing(); hasDrawing = false }
                Button("Прикрепить") {
                    let bounds = canvas.bounds
                    guard bounds.width > 0, bounds.height > 0 else { return }
                    let image = UIGraphicsImageRenderer(size: bounds.size).image { context in
                        UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: bounds.size))
                        canvas.drawing.image(from: bounds, scale: 2).draw(in: CGRect(origin: .zero, size: bounds.size))
                    }
                    if let data = image.jpegData(compressionQuality: 0.9) {
                        selection.selectedPhotosData.append(data)
                        canvas.drawing = PKDrawing(); hasDrawing = false
                    }
                }
                .disabled(!hasDrawing || selection.remainingAttachmentSlots <= reservedSlots)
            }
            .padding()
            PickerDrawingCanvas(canvas: canvas, color: UIColor(color), erasing: erasing, hasDrawing: $hasDrawing)
                .background(Color.white)
        }
    }
}

private struct PickerDrawingCanvas: UIViewRepresentable {
    let canvas: PKCanvasView
    let color: UIColor
    let erasing: Bool
    @Binding var hasDrawing: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.backgroundColor = .white
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.isScrollEnabled = false
        return canvas
    }
    func updateUIView(_ view: PKCanvasView, context: Context) {
        view.tool = erasing ? PKEraserTool(.bitmap) : PKInkingTool(.pen, color: color, width: 5)
    }
    func makeCoordinator() -> Coordinator { Coordinator(hasDrawing: $hasDrawing) }
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let hasDrawing: Binding<Bool>
        init(hasDrawing: Binding<Bool>) { self.hasDrawing = hasDrawing }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { hasDrawing.wrappedValue = !canvasView.drawing.strokes.isEmpty }
    }
}
