//
//  APIError.swift
//  OpenVK for iOS
//
//  Типы ошибок API
//

import Foundation

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case http(Int)
    case decoding(Error)
    case transport(Error)
    case vk(code: Int, message: String)
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный адрес запроса"
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case .http(let code):
            return "Ошибка сервера (HTTP \(code))"
        case .decoding(let error):
            return "Ошибка обработки данных: \(error.localizedDescription)"
        case .transport(let error):
            return error.localizedDescription
        case .vk(let code, let message):
            switch code {
            case 15:
                return "Публикация на этой стене запрещена настройками приватности (Доступ запрещен)."
            case 5:
                return "Ошибка авторизации: неверный или устаревший токен."
            case 14:
                return "Требуется ввод капчи."
            case 17:
                return "Требуется подтверждение действия."
            default:
                return message.isEmpty ? "Код ошибки: \(code)" : "\(message) (код \(code))"
            }
        }
    }
}

struct VKResponseContainer<T: Decodable>: Decodable {
    let response: T?
    let error: VKErrorResponse?
}

struct VKErrorResponse: Decodable {
    let errorCode: Int
    let errorMsg: String

    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case errorMsg = "error_msg"
        case errorCodeCamel = "errorCode"
        case errorMsgCamel = "errorMsg"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        errorCode = (try? container.decode(Int.self, forKey: .errorCode)) ?? (try? container.decode(Int.self, forKey: .errorCodeCamel)) ?? 0
        errorMsg = (try? container.decode(String.self, forKey: .errorMsg)) ?? (try? container.decode(String.self, forKey: .errorMsgCamel)) ?? ""
    }
}
