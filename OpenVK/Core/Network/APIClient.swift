//
//  APIClient.swift
//  OpenVK for iOS
//
//  API клиент для запросов к OpenVK API
//

import Foundation

protocol APIClientProtocol {
    func call<T: Decodable>(
        method: String,
        parameters: [String: String],
        httpMethod: String,
        as type: T.Type
    ) async throws -> T

    func execute<T: Decodable>(
        code: String,
        arguments: [String: String],
        as type: T.Type
    ) async throws -> T

    func upload(
        urlString: String,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> Data

    func call<T: Decodable>(
        method: String,
        parameters: [String: String],
        httpMethod: String,
        as type: T.Type,
        completion: @escaping (Result<T, APIError>) -> Void
    )

    func callWithCache<T: Decodable>(
        method: String,
        parameters: [String: String],
        httpMethod: String,
        cacheKey: String,
        as type: T.Type,
        completion: @escaping (Result<T, APIError>) -> Void
    )

    func execute<T: Decodable>(
        code: String,
        arguments: [String: String],
        as type: T.Type,
        completion: @escaping (Result<T, APIError>) -> Void
    )

    func upload(
        urlString: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        completion: @escaping (Result<Data, APIError>) -> Void
    )
}

final class APIClient: APIClientProtocol {

    static let shared = APIClient()

    private let session: URLSession
    let decoder: JSONDecoder

    private var baseURL: URL {
        AppConfig.apiBaseURL
    }

    init(session: URLSession = .shared) {
        self.session = session
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = dec
    }

    func call<T: Decodable>(
        method: String,
        parameters: [String: String] = [:],
        httpMethod: String = "GET",
        as type: T.Type
    ) async throws -> T {
        let request = try buildRequest(method: method, parameters: parameters, httpMethod: httpMethod)
        return try await perform(request: request, method: method)
    }

    func execute<T: Decodable>(
        code: String,
        arguments: [String: String] = [:],
        as type: T.Type
    ) async throws -> T {
        var params = arguments
        params["code"] = code
        return try await call(method: "execute", parameters: params, httpMethod: "POST", as: type)
    }

    func upload(
        urlString: String,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        let request = buildUploadRequest(url: url, fileData: fileData, fileName: fileName, mimeType: mimeType)
        let (data, _) = try await session.data(for: request)
        return data
    }

    func call<T: Decodable>(
        method: String,
        parameters: [String: String] = [:],
        httpMethod: String = "GET",
        as type: T.Type,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        Task {
            do {
                let result: T = try await call(method: method, parameters: parameters, httpMethod: httpMethod, as: type)
                await MainActor.run { completion(.success(result)) }
            } catch let error as APIError {
                await MainActor.run { completion(.failure(error)) }
            } catch {
                await MainActor.run { completion(.failure(.transport(error))) }
            }
        }
    }

    func callWithCache<T: Decodable>(
        method: String,
        parameters: [String: String] = [:],
        httpMethod: String = "GET",
        cacheKey: String,
        as type: T.Type,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        if let cachedData = CacheService.shared.cachedData(for: cacheKey),
           let container = try? decoder.decode(VKResponseContainer<T>.self, from: cachedData),
           let responseObj = container.response {
            DispatchQueue.main.async { completion(.success(responseObj)) }
            return
        }

        Task {
            do {
                let request = try buildRequest(method: method, parameters: parameters, httpMethod: httpMethod)
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    await MainActor.run { completion(.failure(.invalidResponse)) }
                    return
                }
                if let container = try? decoder.decode(VKResponseContainer<T>.self, from: data) {
                    if let obj = container.response {
                        CacheService.shared.cache(data: data, for: cacheKey)
                        await MainActor.run { completion(.success(obj)) }
                        return
                    } else if let vkError = container.error {
                        if vkError.errorCode == 5 {
                            await MainActor.run { AuthService.shared.signOut() }
                        }
                        await MainActor.run { completion(.failure(.vk(code: vkError.errorCode, message: vkError.errorMsg))) }
                        return
                    }
                }
                guard (200..<300).contains(http.statusCode) else {
                    await MainActor.run { completion(.failure(.http(http.statusCode))) }
                    return
                }
                await MainActor.run { completion(.failure(.invalidResponse)) }
            } catch let error as APIError {
                await MainActor.run { completion(.failure(error)) }
            } catch {
                await MainActor.run { completion(.failure(.transport(error))) }
            }
        }
    }

    func execute<T: Decodable>(
        code: String,
        arguments: [String: String] = [:],
        as type: T.Type,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        Task {
            do {
                let result: T = try await execute(code: code, arguments: arguments, as: type)
                await MainActor.run { completion(.success(result)) }
            } catch let error as APIError {
                await MainActor.run { completion(.failure(error)) }
            } catch {
                await MainActor.run { completion(.failure(.transport(error))) }
            }
        }
    }

    func upload(
        urlString: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        completion: @escaping (Result<Data, APIError>) -> Void
    ) {
        Task {
            do {
                let data = try await upload(urlString: urlString, fileData: fileData, fileName: fileName, mimeType: mimeType)
                await MainActor.run { completion(.success(data)) }
            } catch let error as APIError {
                await MainActor.run { completion(.failure(error)) }
            } catch {
                await MainActor.run { completion(.failure(.transport(error))) }
            }
        }
    }

    private func buildRequest(method: String, parameters: [String: String], httpMethod: String) throws -> URLRequest {
        guard let url = URL(string: "method/\(method)", relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)

        var queryItems = [URLQueryItem(name: "v", value: "5.131")]
        if let token = AuthService.shared.token {
            queryItems.append(URLQueryItem(name: "access_token", value: token))
        }
        for (key, value) in parameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components?.queryItems = queryItems

        guard let requestURL = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")

        if httpMethod == "POST" {
            var formComponents = URLComponents()
            formComponents.queryItems = queryItems
            if let encoded = formComponents.percentEncodedQuery {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = encoded.data(using: .utf8)
            }
        }

        #if DEBUG
        if httpMethod == "POST", let body = request.httpBody.flatMap({ String(data: $0, encoding: .utf8) }) {
            print("[API Request] POST \(requestURL.absoluteString) body: \(body)")
        }
        #endif

        return request
    }

    private func perform<T: Decodable>(request: URLRequest, method: String) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        #if DEBUG
        if let str = String(data: data, encoding: .utf8) {
            print("OpenVK API Response (\(method)), HTTP \(http.statusCode): \(str)")
        }
        #endif

        if let container = try? decoder.decode(VKResponseContainer<T>.self, from: data) {
            if let obj = container.response {
                return obj
            } else if let vkError = container.error {
                if vkError.errorCode == 5 {
                    await MainActor.run { AuthService.shared.signOut() }
                }
                throw APIError.vk(code: vkError.errorCode, message: vkError.errorMsg)
            }
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode)
        }

        do {
            let container = try decoder.decode(VKResponseContainer<T>.self, from: data)
            if let obj = container.response {
                return obj
            } else if let vkError = container.error {
                throw APIError.vk(code: vkError.errorCode, message: vkError.errorMsg)
            } else {
                throw APIError.invalidResponse
            }
        } catch let err as APIError {
            throw err
        } catch {
            #if DEBUG
            print("OpenVK API Decoding Error (\(method)): \(error)")
            #endif
            throw APIError.decoding(error)
        }
    }

    private func buildUploadRequest(url: URL, fileData: Data, fileName: String, mimeType: String) -> URLRequest {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        return request
    }
}
