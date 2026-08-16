//
//  NavigationPanelManager.swift
//  OpenVK for iOS
//

import Foundation
import SwiftUI

class NavigationPanelManager: ObservableObject {
    static let shared = NavigationPanelManager()
    
    @Published var panelItems: [NavigationPanelItem] = []
    @Published var availableItems: [NavigationPanelItem] = []
    @Published var showSectionHeaders: Bool = true
    
    private let panelItemsKey = "navigation_panel_items"
    private let showHeadersKey = "navigation_show_section_headers"
    private let maxPanelItems = 6
    
    private init() {
        loadSettings()
        setupDefaultItems()
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        if let data = defaults.data(forKey: panelItemsKey),
           let decoded = try? JSONDecoder().decode([NavigationPanelItem].self, from: data) {
            panelItems = decoded
        }
        
        showSectionHeaders = defaults.bool(forKey: showHeadersKey)
        if !defaults.contains(showHeadersKey) {
            // По умолчанию заголовки показываются
            showSectionHeaders = true
        }
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        
        if let encoded = try? JSONEncoder().encode(panelItems) {
            defaults.set(encoded, forKey: panelItemsKey)
        }
        
        defaults.set(showSectionHeaders, forKey: showHeadersKey)
        
        defaults.synchronize()
        objectWillChange.send()
    }
    
    private func setupDefaultItems() {
        let allItems = NavigationDestinationType.allCases.map { destinationType in
            NavigationPanelItem(
                id: UUID().uuidString,
                title: destinationType.displayName,
                icon: destinationType.iconName,
                iconFilled: destinationType.iconFilledName,
                destinationType: destinationType,
                isEnabled: destinationType.isMainTab
            )
        }
        
        availableItems = allItems
        
        if panelItems.isEmpty {
            // Основные табы по умолчанию
            let defaultDestinations: [NavigationDestinationType] = [.feed, .search, .messages, .more]
            panelItems = allItems.filter { defaultDestinations.contains($0.destinationType) }
            saveSettings()
        }
    }
    
    var displayPanelItems: [NavigationPanelItem] {
        return Array(panelItems.prefix(maxPanelItems))
    }
    
    var otherSectionItems: [NavigationPanelItem] {
        let panelDestinationTypes = Set(panelItems.map { $0.destinationType })
        return availableItems.filter { 
            !panelDestinationTypes.contains($0.destinationType) && $0.destinationType != .more
        }
    }
    
    func addToPanel(_ item: NavigationPanelItem) {
        guard !panelItems.contains(where: { $0.destinationType == item.destinationType }) else { return }
        guard panelItems.count < maxPanelItems else { return }
        
        panelItems.append(item)
        saveSettings()
    }
    
    func removeFromPanel(_ item: NavigationPanelItem) {
        guard item.destinationType != .more else { return }
        
        panelItems.removeAll { $0.destinationType == item.destinationType }
        saveSettings()
    }
    
    func movePanelItems(from source: IndexSet, to destination: Int) {
        panelItems.move(fromOffsets: source, toOffset: destination)
        saveSettings()
    }
    
    func updateShowHeaders(_ show: Bool) {
        showSectionHeaders = show
        saveSettings()
    }
    
    func item(for destinationType: NavigationDestinationType) -> NavigationPanelItem? {
        return availableItems.first { $0.destinationType == destinationType }
    }
    
    func resetToDefaults() {
        let defaultDestinations: [NavigationDestinationType] = [.feed, .search, .messages, .more]
        panelItems = availableItems.filter { defaultDestinations.contains($0.destinationType) }
        showSectionHeaders = true
        saveSettings()
    }
}
