//
//  ReportsService.swift
//  OpenVK for iOS
//

import Foundation

protocol ReportsServiceProtocol {
    func addReport(ownerID: Int, type: String, comment: String, completion: @escaping (Result<Void, Error>) -> Void)
}

final class ReportsService: ReportsServiceProtocol {
    static let shared = ReportsService()
    private let client: APIClientProtocol

    private init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    func addReport(ownerID: Int, type: String, comment: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let params: [String: String] = [
            "owner_id": "\(ownerID)",
            "type": type,
            "comment": comment
        ]

        client.call(method: "reports.add", parameters: params, httpMethod: "POST", as: Int.self) { result in
            switch result {
            case .success(_):
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
