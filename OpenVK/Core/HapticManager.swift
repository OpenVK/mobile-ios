//
//  HapticManager.swift
//  OpenVK for iOS
//

import UIKit
import AVFoundation

enum HapticManager {
    private static var messageSoundPlayer: AVAudioPlayer?
    private static var messageSoundDelegate: MessageSoundDelegate?
    private static var previousAudioSession: AudioSessionConfiguration?

    private struct AudioSessionConfiguration {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
    }

    private final class MessageSoundDelegate: NSObject, AVAudioPlayerDelegate {
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            HapticManager.restoreAudioSession()
        }
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    static func playMessageSound() {
        guard let url = Bundle.main.url(forResource: "Web_static_audio_notify", withExtension: "mp3") else { return }
        do {
            if messageSoundPlayer?.isPlaying == true {
                messageSoundPlayer?.stop()
                restoreAudioSession()
            }
            let session = AVAudioSession.sharedInstance()
            previousAudioSession = AudioSessionConfiguration(
                category: session.category,
                mode: session.mode,
                options: session.categoryOptions
            )
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            messageSoundPlayer = try AVAudioPlayer(contentsOf: url)
            messageSoundDelegate = MessageSoundDelegate()
            messageSoundPlayer?.delegate = messageSoundDelegate
            messageSoundPlayer?.prepareToPlay()
            messageSoundPlayer?.play()
        } catch {
            restoreAudioSession()
            #if DEBUG
            print("Failed to play message notification sound: \(error)")
            #endif
        }
    }

    private static func restoreAudioSession() {
        guard let previousAudioSession else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            previousAudioSession.category,
            mode: previousAudioSession.mode,
            options: previousAudioSession.options
        )
        try? session.setActive(true)
        self.previousAudioSession = nil
        messageSoundDelegate = nil
    }
}
