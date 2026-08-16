//
//  DocumentDownloader.swift
//  OpenVK for iOS
//

import Foundation
import UIKit
import SwiftUI

enum DocumentDownloader {
    static func downloadAndShare(url urlString: String, title: String, ext: String, isDownloading: Binding<Bool>? = nil) {
        guard let url = URL(string: urlString) else { return }
        
        isDownloading?.wrappedValue = true
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            DispatchQueue.main.async {
                isDownloading?.wrappedValue = false
            }
            
            if let localURL = localURL {
                let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let safeTitle = cleanedTitle.isEmpty ? "document" : cleanedTitle
                let safeExt = ext.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                let tempDirectory = FileManager.default.temporaryDirectory
                let filename: String
                if safeExt.isEmpty {
                    filename = safeTitle
                } else if safeTitle.lowercased().hasSuffix(".\(safeExt)") {
                    filename = safeTitle
                } else {
                    filename = "\(safeTitle).\(safeExt)"
                }
                
                let destinationURL = tempDirectory.appendingPathComponent(filename)
                
                try? FileManager.default.removeItem(at: destinationURL)
                
                do {
                    try FileManager.default.moveItem(at: localURL, to: destinationURL)
                    
                    DispatchQueue.main.async {
                        presentShareSheet(for: destinationURL)
                    }
                } catch {
                    print("Error moving downloaded document: \(error)")
                }
            } else if let error = error {
                print("Error downloading document: \(error)")
            }
        }
        task.resume()
    }
    
    private static func presentShareSheet(for fileURL: URL) {
        let av = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let topVC = getTopmostViewController() {
            if let popover = av.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topVC.present(av, animated: true, completion: nil)
        }
    }
}
