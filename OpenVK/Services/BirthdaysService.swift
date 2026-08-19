//
//  BirthdaysService.swift
//  OpenVK for iOS
//
//  Ближайшие дни рождения друзей.
//

import Foundation

protocol BirthdaysServiceProtocol {
    func fetchUpcomingBirthdays(completion: @escaping (Result<[Birthday], Error>) -> Void)
}

final class BirthdaysService: BirthdaysServiceProtocol {

    static let shared = BirthdaysService()

    private let maxFriendsPerPage = 100

    private init() {}

    func fetchUpcomingBirthdays(completion: @escaping (Result<[Birthday], Error>) -> Void) {
        fetchUpcomingBirthdays(maxFriends: 500, completion: completion)
    }

    func fetchUpcomingBirthdays(maxFriends: Int, completion: @escaping (Result<[Birthday], Error>) -> Void) {
        fetchPage(offset: 0, collected: [], maxFriends: maxFriends, completion: completion)
    }

    private func fetchPage(
        offset: Int,
        collected: [VKUserProfile],
        maxFriends: Int,
        completion: @escaping (Result<[Birthday], Error>) -> Void
    ) {
        APIClient.shared.call(
            method: "friends.get",
            parameters: [
                "fields": "bdate,photo_100,photo_200,online,status,last_seen",
                "count": "\(maxFriendsPerPage)",
                "offset": "\(offset)"
            ],
            httpMethod: "GET",
            as: VKSearchResponseInner<VKUserProfile>.self
        ) { [weak self] (result: Result<VKSearchResponseInner<VKUserProfile>, APIError>) in
            guard let self = self else { return }
            switch result {
            case .success(let inner):
                let items = inner.items ?? []
                let total = inner.count ?? 0
                let all = collected + items
                let wanted = min(maxFriends, total)
                if all.count < wanted && !items.isEmpty {
                    self.fetchPage(offset: offset + items.count, collected: all, maxFriends: maxFriends, completion: completion)
                } else {
                    completion(.success(self.mapBirthdays(all)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func mapBirthdays(_ profiles: [VKUserProfile]) -> [Birthday] {
        let birthdays = profiles.compactMap { profile -> Birthday? in
            guard let bdate = profile.bdate, bdate != "01.01.1970" else { return nil }
            let name = "\(profile.firstName ?? "") \(profile.lastName ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
            let user = User(
                uid: profile.id,
                username: profile.screenName ?? "id\(profile.id)",
                displayName: name.isEmpty ? "Пользователь" : name,
                avatarURL: (profile.photo200 ?? profile.photo100).flatMap { URL(string: $0) },
                isOnline: profile.online == 1,
                onlinePlatform: profile.lastSeen?.platformName
            )
            return Birthday.parse(bdate: bdate, user: user)
        }
        return birthdays.sorted {
            if $0.daysUntil != $1.daysUntil {
                return $0.daysUntil < $1.daysUntil
            }
            return $0.user.displayName.localizedStandardCompare($1.user.displayName) == .orderedAscending
        }
    }
}
