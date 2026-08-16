//
//  DocumentsService.swift
//  OpenVK for iOS
//
//  Сервис работы с документами.
//

import Foundation

protocol DocumentsServiceProtocol {
    func fetchMyDocuments(offset: Int, count: Int, completion: @escaping (Result<[AppDocument], Error>) -> Void)
    func searchDocuments(query: String, searchOwn: Int, offset: Int, count: Int, completion: @escaping (Result<[AppDocument], Error>) -> Void)
    func addDocument(ownerID: Int, docID: Int, accessKey: String?, completion: @escaping (Result<Bool, Error>) -> Void)
    func deleteDocument(ownerID: Int, docID: Int, completion: @escaping (Result<Bool, Error>) -> Void)
}

final class DocumentsService: DocumentsServiceProtocol {
    
    static let shared = DocumentsService()
    
    private init() {}

    func fetchMyDocuments(offset: Int = 0, count: Int = 30, completion: @escaping (Result<[AppDocument], Error>) -> Void) {
        let params: [String: String] = [
            "count": "\(count)",
            "offset": "\(offset)"
        ]
        
        APIClient.shared.call(
            method: "docs.get",
            parameters: params,
            httpMethod: "GET",
            as: VKDocumentResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let items = (response.items ?? []).map { $0.toAppDocument() }
                completion(.success(items))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func searchDocuments(query: String, searchOwn: Int = 0, offset: Int = 0, count: Int = 30, completion: @escaping (Result<[AppDocument], Error>) -> Void) {
        var params: [String: String] = [
            "q": query,
            "search_own": "\(searchOwn)",
            "count": "\(count)",
            "offset": "\(offset)"
        ]
        
        APIClient.shared.call(
            method: "docs.search",
            parameters: params,
            httpMethod: "GET",
            as: VKDocumentResponse.self
        ) { result in
            switch result {
            case .success(let response):
                let items = (response.items ?? []).map { $0.toAppDocument() }
                completion(.success(items))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func addDocument(ownerID: Int, docID: Int, accessKey: String? = nil, completion: @escaping (Result<Bool, Error>) -> Void) {
        var params: [String: String] = [
            "owner_id": "\(ownerID)",
            "doc_id": "\(docID)"
        ]
        if let key = accessKey, !key.isEmpty {
            params["access_key"] = key
        }

        struct AddDocResponse: Decodable {
            let response: String?
        }

        APIClient.shared.call(
            method: "docs.add",
            parameters: params,
            httpMethod: "POST",
            as: AddDocResponse.self
        ) { result in
            switch result {
            case .success:
                completion(.success(true))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func deleteDocument(ownerID: Int, docID: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        let params: [String: String] = [
            "owner_id": "\(ownerID)",
            "doc_id": "\(docID)"
        ]

        struct DeleteDocResponse: Decodable {
            let response: Int?
        }

        APIClient.shared.call(
            method: "docs.delete",
            parameters: params,
            httpMethod: "POST",
            as: DeleteDocResponse.self
        ) { result in
            switch result {
            case .success:
                completion(.success(true))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
