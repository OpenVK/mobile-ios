//
//  BirthdaysViewModel.swift
//  OpenVK for iOS
//
//  Состояние экрана ближайших дней рождения.
//

import Foundation

final class BirthdaysViewModel: ObservableObject {

    static let nearbyWindowDays = 7

    @Published private(set) var birthdays: [Birthday] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// Только те дни рождения, что наступят в ближайшую неделю.
    @Published private(set) var nearbyBirthdays: [Birthday] = []

    private let service: BirthdaysServiceProtocol
    private var hasLoaded = false

    init(service: BirthdaysServiceProtocol = BirthdaysService.shared) {
        self.service = service
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        load()
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        service.fetchUpcomingBirthdays { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            self.hasLoaded = true
            switch result {
            case .success(let birthdays):
                self.birthdays = birthdays
                self.nearbyBirthdays = birthdays.filter { $0.daysUntil <= Self.nearbyWindowDays }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
