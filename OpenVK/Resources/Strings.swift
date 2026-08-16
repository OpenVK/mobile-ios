//
//  Strings.swift
//  OpenVK for iOS
//
//  Строки UI.
//

import Foundation

enum L10n {

    enum Auth {
        static let welcome        = "Welcome to OpenVK"
        static let subtitle       = "Not-yet-federated open source\nsocial network inspired by VK. "
        static let instance                  = "Инстанция"
        static let customInstance            = "Другая"
        static let customInstancePlaceholder = "domain.com"
        static let email          = "Email"
        static let password       = "Password"
        static let signIn         = "Sign In"
        static let `continue`     = "Continue"
        static let forgot         = "Forgot password?"
        static let noAccount      = "Don't have an account?"
        static let createAccount  = "Create account now"
        static let disclaimer     = "OpenVK it is fan project, not affiliated in any way with VKontakte and it's company VK LLC."
    }

    enum Feed {
        static let title    = "Лента"
        static let newPost  = "Новая запись"
    }

    enum Search {
        static let title       = "Поиск"
        static let placeholder = "Люди, группы, записи..."
        static let hint        = "Введите запрос"
    }

    enum Messages {
        static let title = "Сообщения"
        static let empty = "Нет сообщений"
    }

    enum Profile {
        static let edit          = "Редактировать"
        static let photosHeader  = "ФОТОГРАФИИ"
        static let postsHeader   = "ЗАПИСИ"
        static let cityPrefix    = "Город:"
        static let details       = "Подробная информация"
    }

    enum More {
        static let unavailable = "Недоступно"
    }

    enum NewPost {
        static let title       = "Новая запись"
        static let placeholder = "Что у вас нового?"
        static let cancel      = "Отмена"
        static let publish     = "Опубликовать"
        static let photo       = "Фото"
        static let visibility  = "Публичная запись"
    }
    
    enum TwoFactor {
        static let title         = "Подтверждение входа"
        static let subtitle      = "Введите код из приложения-аутентификатора"
        static let confirm       = "Подтвердить"
        static let resend        = "Отправить код повторно"
        static let anotherMethod = "Использовать другой способ"
        static let disclaimer    = "Код действителен 5 минут.\nНикому не сообщайте его."
        static let invalidCode   = "Неверный или устаревший код. Попробуйте ещё раз."
        static let resendFailed  = "Не удалось отправить код. Попробуйте позже."
 
        static func resendIn(_ seconds: Int) -> String {
            "Повторно через \(seconds) с"
        }
    }
}
