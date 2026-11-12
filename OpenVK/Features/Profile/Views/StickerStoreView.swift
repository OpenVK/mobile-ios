import SwiftUI

struct StickerStoreView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "face.smiling")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Раздел в разработке")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Стикеры")
        .navigationBarTitleDisplayMode(.inline)
    }
}
