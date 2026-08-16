//
//  UserDefaults+Extensions.swift
//  OpenVK for iOS
//
//  Вспомогательные расширения для UserDefaults.
//

import Foundation

extension UserDefaults {
    func contains(_ key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
