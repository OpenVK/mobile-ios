//
//  DocumentsListView.swift
//  OpenVK for iOS
//

import SwiftUI

struct DocumentsListView: View {

    @StateObject private var viewModel = DocumentsViewModel()
    @State private var downloadingDocID: Int? = nil
    @State private var isDownloading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            mainContent
        }
        .navigationBarTitle("Документы", displayMode: .inline)
        .onAppear {
            viewModel.loadInitialData()
        }
        .alert(isPresented: Binding(
            get: { viewModel.errorMessage != nil || viewModel.statusMessage != nil },
            set: { _ in
                viewModel.errorMessage = nil
                viewModel.statusMessage = nil
            }
        )) {
            if let error = viewModel.errorMessage {
                return Alert(title: Text("Ошибка"), message: Text(error), dismissButton: .default(Text("ОК")))
            } else {
                return Alert(title: Text("Информация"), message: Text(viewModel.statusMessage ?? ""), dismissButton: .default(Text("ОК")))
            }
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            TextField("Поиск документов...", text: $viewModel.searchQuery)
                .font(.system(size: 15))
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoadingMy && viewModel.myDocuments.isEmpty {
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            }
        } else if !viewModel.isSearching {
            // Обычный режим (список моих документов с пагинацией)
            if viewModel.myDocuments.isEmpty {
                emptyMyDocumentsView
            } else {
                List {
                    Section(header: Text("Мои документы")) {
                        ForEach(viewModel.myDocuments) { doc in
                            makeDocumentRow(doc)
                                .onAppear {
                                    if doc.id == viewModel.myDocuments.last?.id {
                                        viewModel.loadMoreMyDocuments()
                                    }
                                }
                        }

                        if viewModel.isLoadingMoreMy {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 8)
                                Spacer()
                            }
                        }
                    }
                }
                .listStyle(GroupedListStyle())
                .refreshable {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        viewModel.refresh {
                            continuation.resume()
                        }
                    }
                }
            }
        } else {
            List {
                if !viewModel.localSearchResults.isEmpty {
                    Section(header: Text("Мои документы")) {
                        ForEach(viewModel.localSearchResults) { doc in
                            makeDocumentRow(doc)
                        }
                    }
                }

                Section(header: Text("Глобальный поиск")) {
                    if viewModel.isGlobalSearching && viewModel.globalSearchResults.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 12)
                            Spacer()
                        }
                    } else if viewModel.globalSearchResults.isEmpty {
                        Text("Ничего не найдено по запросу «\(viewModel.searchQuery)»")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(viewModel.globalSearchResults) { doc in
                            makeDocumentRow(doc)
                                .onAppear {
                                    if doc.id == viewModel.globalSearchResults.last?.id {
                                        viewModel.loadMoreGlobal()
                                    }
                                }
                        }

                        if viewModel.isLoadingMoreGlobal {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 8)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .refreshable {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    viewModel.refresh {
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func makeDocumentRow(_ doc: AppDocument) -> some View {
        DocumentRow(
            doc: doc,
            isDownloading: downloadingDocID == doc.id && isDownloading,
            onViewDownload: {
                downloadingDocID = doc.id
                DocumentDownloader.downloadAndShare(
                    url: doc.url,
                    title: doc.title,
                    ext: doc.ext,
                    isDownloading: $isDownloading
                )
            },
            onAdd: {
                viewModel.addDocument(doc)
            },
            onDelete: {
                viewModel.deleteDocument(doc)
            }
        )
    }

    private var emptyMyDocumentsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Color(.tertiaryLabel))
            Text("У вас пока нет сохраненных документов")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

private struct DocumentRow: View {
    let doc: AppDocument
    let isDownloading: Bool
    let onViewDownload: () -> Void
    let onAdd: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(doc.iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: doc.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(doc.iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(doc.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !doc.ext.isEmpty {
                        Text(doc.ext.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemBackground))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }

                    Text(doc.formattedSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 8)

            if isDownloading {
                ProgressView()
                    .frame(width: 32, height: 32)
            } else {
                Menu {
                    if !doc.isOwn {
                        Button(action: onAdd) {
                            Label("Сохранить к себе", systemImage: "plus.square.on.square")
                        }
                    }

                    if doc.isOwn {
                        Button(role: .destructive, action: onDelete) {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onViewDownload()
        }
    }
}
