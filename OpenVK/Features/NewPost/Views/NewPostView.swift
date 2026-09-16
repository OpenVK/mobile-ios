//
//  NewPostView.swift
//  OpenVK for iOS
//

import SwiftUI
import PhotosUI
import UIKit

struct NewPostView: View {

    @Binding var isPresented: Bool
    let ownerID: Int?
    let targetUser: User?
    var onPostCreated: ((Post) -> Void)?
    @StateObject private var viewModel: NewPostViewModel
    @State private var showImagePicker: Bool = false
    @State private var showPostOptions: Bool = false
    @State private var editorFocused: Bool = false

    init(isPresented: Binding<Bool>, ownerID: Int? = nil, targetUser: User? = nil, onPostCreated: ((Post) -> Void)? = nil) {
        self._isPresented = isPresented
        self.ownerID = ownerID ?? targetUser?.uid
        self.targetUser = targetUser
        self.onPostCreated = onPostCreated
        self._viewModel = StateObject(wrappedValue: NewPostViewModel(ownerID: ownerID, targetUser: targetUser))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                NewPostTopBar(
                    canPublish: viewModel.canPublish,
                    onCancel: {
                        editorFocused = false
                        isPresented = false
                    },
                    onPublish: {
                        editorFocused = false
                        viewModel.publish { post in
                            onPostCreated?(post)
                            isPresented = false
                        }
                    }
                )

                Divider()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        NewPostAuthorHeader(
                            targetUser: viewModel.targetUser ?? targetUser,
                            isGroup: viewModel.isGroup
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editorFocused = false
                        }

                        NewPostEditor(
                            text: $viewModel.text,
                            isFocused: $editorFocused,
                            height: editorHeight(for: geometry.size.height)
                        )

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
                                                    editorFocused = false
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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editorFocused = false
                            }
                        }

                        Spacer(minLength: 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .newPostKeyboardScrollDismissal()

                Divider()

                NewPostAttachmentsBar(
                    showImagePicker: $showImagePicker,
                    showPostOptions: $showPostOptions,
                    dismissKeyboard: {
                        editorFocused = false
                    }
                )
                .background(Color(.systemBackground))
            }
            .background(Color(.systemBackground))
            .background(NewPostKeyboardDismissInstaller())
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .newPostSheetHeight(preferredSheetHeight)
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

    private var preferredSheetHeight: CGFloat {
        // Natural compact size: top bar + author + 120 pt editor + bottom bar.
        // Photos add one fixed-height horizontal strip. The second detent is .large,
        // so dragging the sheet upward gives the editor the remaining screen space.
        296 + (viewModel.selectedPhotosData.isEmpty ? 0 : 128)
    }

    private func editorHeight(for availableHeight: CGFloat) -> CGFloat {
        let fixedHeight: CGFloat = 176 + (viewModel.selectedPhotosData.isEmpty ? 0 : 128)
        let isExpanded = availableHeight > preferredSheetHeight + 80
        return isExpanded ? max(120, availableHeight - fixedHeight) : 120
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

private extension View {
    @ViewBuilder
    func newPostSheetHeight(_ height: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            self.modifier(NewPostSheetDetentsModifier(compactHeight: height))
        } else {
            self.background(LegacyNewPostSheetConfigurator())
        }
    }

    @ViewBuilder
    func newPostKeyboardScrollDismissal() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}

@available(iOS 16.0, *)
private struct NewPostSheetDetentsModifier: ViewModifier {
    let compactHeight: CGFloat
    @State private var selectedDetent: PresentationDetent

    init(compactHeight: CGFloat) {
        self.compactHeight = compactHeight
        _selectedDetent = State(initialValue: .height(compactHeight))
    }

    func body(content: Content) -> some View {
        content
            .presentationDetents(
                [.height(compactHeight), .large],
                selection: $selectedDetent
            )
            .presentationDragIndicator(.visible)
            .onChange(of: compactHeight) { newHeight in
                // Keep the composer compact when attachments change its natural
                // height, but preserve an explicitly selected full-screen detent.
                if selectedDetent != .large {
                    selectedDetent = .height(newHeight)
                }
            }
    }
}

private struct LegacyNewPostSheetConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SheetConfiguratorViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class SheetConfiguratorViewController: UIViewController {
        private var hasConfigured = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configureSheetIfNeeded()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            configureSheetIfNeeded()
        }

        private func configureSheetIfNeeded() {
            guard !hasConfigured else { return }

            var controller: UIViewController = self
            while let parent = controller.parent {
                controller = parent
            }

            guard let sheet = controller.presentationController as? UISheetPresentationController else {
                return
            }

            hasConfigured = true
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .medium
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            enableInteractiveKeyboardDismiss(in: controller.view)
        }

        private func enableInteractiveKeyboardDismiss(in view: UIView) {
            if let scrollView = view as? UIScrollView {
                scrollView.keyboardDismissMode = .interactive
            }
            for subview in view.subviews {
                enableInteractiveKeyboardDismiss(in: subview)
            }
        }
    }
}

private struct NewPostTopBar: View {
    let canPublish: Bool
    let onCancel: () -> Void
    let onPublish: () -> Void

    private var isIOS26OrNewer: Bool {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return true
        }
#endif
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(L10n.NewPost.cancel, action: onCancel)
                .font(.system(size: 15))
                .foregroundColor(.appAccent)

            Spacer(minLength: 12)

            Button(action: onPublish) {
                Text(L10n.NewPost.publish)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(canPublish ? .appAccent : Color(.secondaryLabel))
            }
            .disabled(!canPublish)
        }
        .padding(.horizontal, isIOS26OrNewer ? 20 : 16)
        .padding(.top, isIOS26OrNewer ? 20 : 0)
        .padding(.bottom, isIOS26OrNewer ? 12 : 0)
        .frame(height: isIOS26OrNewer ? nil : 44)
        .background(Color(.systemBackground))
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
    @Binding var isFocused: Bool
    let height: CGFloat

    var body: some View {
        CaretTrackingTextView(
            text: $text,
            isFocused: $isFocused,
            placeholder: L10n.NewPost.placeholder
        )
        .frame(height: height)
        .padding(.top, 4)
    }
}

private struct CaretTrackingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.tintColor = UIColor(Color.appAccent)
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let label = UILabel()
        label.text = placeholder
        label.font = textView.font
        label.textColor = .placeholderText
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(lessThanOrEqualTo: textView.bottomAnchor, constant: -8)
        ])
        context.coordinator.placeholderLabel = label
        label.isHidden = !text.isEmpty

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            let selection = textView.selectedRange
            textView.text = text
            textView.selectedRange = NSRange(
                location: min(selection.location, (text as NSString).length),
                length: 0
            )
        }
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty

        if isFocused {
            if !context.coordinator.isResigning && !textView.isFirstResponder {
                textView.becomeFirstResponder()
            }
        } else {
            context.coordinator.isResigning = false
            if textView.isFirstResponder {
                textView.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CaretTrackingTextView
        var placeholderLabel: UILabel?
        var isResigning: Bool = false

        init(parent: CaretTrackingTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isResigning = false
            placeholderLabel?.isHidden = !textView.text.isEmpty
            if !parent.isFocused {
                DispatchQueue.main.async {
                    self.parent.isFocused = true
                }
            }
            scrollCaretIntoView(textView, animated: false)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isResigning = true
            placeholderLabel?.isHidden = !textView.text.isEmpty
            if parent.isFocused {
                DispatchQueue.main.async {
                    self.parent.isFocused = false
                }
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            placeholderLabel?.isHidden = !textView.text.isEmpty
            scrollCaretIntoView(textView, animated: false)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            scrollCaretIntoView(textView, animated: false)
        }

        func scrollCaretIntoView(_ textView: UITextView, animated: Bool) {
            DispatchQueue.main.async {
                guard textView.isFirstResponder,
                      let selectedRange = textView.selectedTextRange else {
                    return
                }

                var caretRect = textView.caretRect(for: selectedRange.end)
                caretRect = caretRect.insetBy(dx: 0, dy: -10)
                textView.scrollRectToVisible(caretRect, animated: animated)
            }
        }
    }
}

private struct NewPostAttachmentsBar: View {
    @Binding var showImagePicker: Bool
    @Binding var showPostOptions: Bool
    let dismissKeyboard: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                dismissKeyboard()
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
                dismissKeyboard()
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
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
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

private struct NewPostKeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        KeyboardDismissInstallerView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        (uiView as? KeyboardDismissInstallerView)?.uninstall()
    }

    private final class KeyboardDismissInstallerView: UIView, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private var tapRecognizer: UITapGestureRecognizer?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            installIfNeeded()
        }

        func uninstall() {
            if let tapRecognizer, let installedWindow {
                installedWindow.removeGestureRecognizer(tapRecognizer)
            }
            tapRecognizer = nil
            installedWindow = nil
        }

        private func installIfNeeded() {
            guard let window, installedWindow !== window else { return }
            uninstall()

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            tapRecognizer = recognizer
            installedWindow = window
        }

        @objc private func handleTap() {
            installedWindow?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextView {
                    return false
                }
                view = current.superview
            }
            return true
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
