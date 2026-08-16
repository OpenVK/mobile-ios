//
//  PostDetailLoaderView.swift
//  OpenVK for iOS
//

import SwiftUI

struct PostDetailLoaderView: View {
    let ownerID: Int
    let postID: Int
    @Binding var selectedMedia: Attachment?
    @Binding var owningPost: Post?
    
    @State private var post: Post? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    init(
        ownerID: Int,
        postID: Int,
        selectedMedia: Binding<Attachment?> = .constant(nil),
        owningPost: Binding<Post?> = .constant(nil)
    ) {
        self.ownerID = ownerID
        self.postID = postID
        self._selectedMedia = selectedMedia
        self._owningPost = owningPost
    }
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Загрузка записи...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let post = post {
                PostDetailView(post: post, selectedMedia: $selectedMedia, owningPost: $owningPost)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button("Повторить") {
                        loadPost()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.appAccent)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitle("Запись", displayMode: .inline)
        .onAppear {
            if post == nil {
                loadPost()
            }
        }
    }
    
    private func loadPost() {
        isLoading = true
        errorMessage = nil
        
        FeedService.shared.getPostById(ownerID: ownerID, postID: postID) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let fetchedPost):
                    self.post = fetchedPost
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
