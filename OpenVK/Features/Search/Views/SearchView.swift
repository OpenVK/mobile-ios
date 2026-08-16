//
//  SearchView.swift
//  OpenVK for iOS
//

import SwiftUI

struct SearchView: View {

    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?

    init(selectedMedia: Binding<Attachment?> = .constant(nil), owningPost: Binding<Post?> = .constant(nil)) {
        self._selectedMedia = selectedMedia
        self._owningPost = owningPost
    }

    var body: some View {
        NavigationView {
            UnderDevelopmentView(section: "Поиск")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
                .navigationBarTitle(L10n.Search.title)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
