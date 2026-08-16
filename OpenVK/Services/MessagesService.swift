//
//  MessagesService.swift
//  OpenVK for iOS
//

import Foundation

protocol MessagesServiceProtocol {
    func fetchConversations(offset: Int, count: Int, completion: @escaping (Result<[Conversation], Error>) -> Void)
    func fetchMessages(peerID: Int, offset: Int, count: Int, completion: @escaping (Result<[Message], Error>) -> Void)
    func send(text: String, to peerID: Int, completion: @escaping (Result<Int, Error>) -> Void)
    func edit(messageID: Int, newText: String, completion: @escaping (Result<Void, Error>) -> Void)
    func delete(messageIDs: [Int], completion: @escaping (Result<Void, Error>) -> Void)
}

final class MessagesService: MessagesServiceProtocol {

    static let shared = MessagesService()
    private let client: APIClientProtocol

    private init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    func fetchConversations(offset: Int = 0, count: Int = 20, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        let params: [String: String] = [
            "offset": "\(offset)",
            "count": "\(count)",
            "extended": "1",
            "fields": "id,first_name,last_name,screen_name,photo_100,online,last_seen,verified"
        ]

        client.call(method: "messages.getConversations", parameters: params, httpMethod: "GET", as: VKConversationsResponse.self) { result in
            switch result {
            case .success(let response):
                let profiles = response.profiles ?? []

                let conversations = response.items.map { item -> Conversation in
                    let peerID = item.conversation.peer.id
                    let peerUser: User

                    if let profile = profiles.first(where: { $0.id == peerID }) {
                        let name = "\(profile.firstName ?? "") \(profile.lastName ?? "")".trimmingCharacters(in: .whitespaces)
                        peerUser = User(
                            uid: peerID,
                            username: profile.screenName ?? "id\(peerID)",
                            displayName: name.isEmpty ? "Пользователь" : name,
                            avatarURL: profile.photo100.flatMap { URL(string: $0) },
                            isOnline: profile.online == 1,
                            onlinePlatform: profile.lastSeen?.platformName,
                            isOfficial: profile.verified == 1
                        )
                    } else {
                        peerUser = User(uid: peerID, username: "id\(peerID)", displayName: "Пользователь \(peerID)")
                    }

                    let lastMessageBody = item.lastMessage?.body ?? ""
                    let timestamp: TimeInterval
                    if let dateInt = item.lastMessage?.date {
                        timestamp = TimeInterval(dateInt)
                    } else {
                        timestamp = Date().timeIntervalSince1970
                    }
                    let date = Date(timeIntervalSince1970: timestamp)

                    return Conversation(
                        peer: peerUser,
                        lastMessage: lastMessageBody,
                        lastMessageOutgoing: item.lastMessage?.out == 1,
                        updatedAt: date,
                        unreadCount: item.conversation.unreadCount ?? 0,
                        lastMessageId: item.conversation.lastMessageId
                    )
                }

                completion(.success(conversations))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchMessages(peerID: Int, offset: Int = 0, count: Int = 20, completion: @escaping (Result<[Message], Error>) -> Void) {
        let params: [String: String] = [
            "user_id": "\(peerID)",
            "offset": "\(offset)",
            "count": "\(count)",
            "extended": "1",
            "fields": "id,first_name,last_name,screen_name,photo_100"
        ]

        client.call(method: "messages.getHistory", parameters: params, httpMethod: "GET", as: VKMessageHistoryResponse.self) { result in
            switch result {
            case .success(let response):
                let messages = response.items.map { item -> Message in
                    let direction: Message.Direction = item.out == 1 ? .outgoing : .incoming
                    let text = item.text ?? item.body ?? ""
                    let date = Date(timeIntervalSince1970: TimeInterval(item.date))
                    return Message(
                        id: item.id,
                        peerId: item.peerId ?? peerID,
                        fromId: item.fromId,
                        text: text,
                        date: date,
                        direction: direction
                    )
                }
                completion(.success(messages))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func send(text: String, to peerID: Int, completion: @escaping (Result<Int, Error>) -> Void) {
        let params: [String: String] = [
            "user_id": "\(peerID)",
            "message": text,
            "random_id": "\(Int(Date().timeIntervalSince1970 * 1000))"
        ]

        client.call(method: "messages.send", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success(let messageID):
                completion(.success(messageID))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func edit(messageID: Int, newText: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let params: [String: String] = [
            "message_id": "\(messageID)",
            "message": newText
        ]

        client.call(method: "messages.edit", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func delete(messageIDs: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
        let params: [String: String] = [
            "message_ids": messageIDs.map(String.init).joined(separator: ","),
            "delete_for_all": "1"
        ]

        client.call(method: "messages.delete", parameters: params, httpMethod: "POST", as: [String: Int].self) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
