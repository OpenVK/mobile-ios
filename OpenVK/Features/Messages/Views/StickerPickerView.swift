//
//  StickerPickerView.swift
//  OpenVK for iOS
//

import SwiftUI

struct StickerPickerView: View {

    var onSelectSticker: (Sticker) -> Void

    @State private var stickerPacks: [StickerPack] = []
    @State private var selectedPackId: Int? = nil
    @State private var isLoading = false

    var selectedPack: StickerPack? {
        stickerPacks.first(where: { $0.id == selectedPackId }) ?? stickerPacks.first
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && stickerPacks.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 220)
            } else if let pack = selectedPack, !pack.stickers.isEmpty {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(pack.stickers) { sticker in
                            Button(action: { onSelectSticker(sticker) }) {
                                RemoteImage(url: sticker.imageURL, placeholder: ProgressView())
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(height: 220)
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "face.smiling")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Нет доступных стикеров")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 220)
            }

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stickerPacks) { pack in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedPackId = pack.id
                            }
                        }) {
                            ZStack {
                                if let icon = pack.iconURL {
                                    RemoteImage(url: icon, placeholder: Color.clear)
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    Image(systemName: "square.grid.2x2.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedPackId == pack.id ? .appAccent : .secondary)
                                }
                            }
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedPackId == pack.id ? Color(.secondarySystemFill) : Color.clear)
                            )
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .background(Color(.systemBackground))
        }
        .background(Color(.secondarySystemBackground))
        .onAppear {
            loadPacks()
        }
    }

    private func loadPacks() {
        isLoading = true
        MessagesService.shared.fetchStickerPacks { result in
            DispatchQueue.main.async {
                isLoading = false
                if case .success(let packs) = result {
                    stickerPacks = packs
                    if selectedPackId == nil {
                        selectedPackId = packs.first?.id
                    }
                }
            }
        }
    }
}
