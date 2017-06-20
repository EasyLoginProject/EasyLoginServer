 import Foundation
 import Kitura
 import KituraNet
 
 public enum EasyLoginError {
    case forbidden
    case notFound
    case malformedBody
    case missingField(String)
    case validation(String)
    case databaseNotAvailable
    case debug(String?)
 }
 
 extension EasyLoginError {
    func statusCode() -> HTTPStatusCode {
        switch self {
        case .forbidden:
            return .forbidden
        case .notFound:
            return .notFound
        case .malformedBody, .missingField, .validation:
            return .preconditionFailed
        case .databaseNotAvailable:
            return .internalServerError
        default:
            return .internalServerError
        }
    }
    
    func message() -> String? {
        switch self {
        case .malformedBody:
            return "Malformed body"
        case .missingField(let fieldName):
            return "Missing field \(fieldName)"
        case .validation(let fieldName):
            return "Validation error on \(fieldName)"
        case .databaseNotAvailable:
            return "Database not available"
        case .debug(let message):
            return message ?? "Internal error"
        default:
            return nil
        }
    }
 }
 
 public func sendError(_ error: EasyLoginError = .debug("Default error"), to response: RouterResponse) {
    response.statusCode = error.statusCode()
    if let message = error.message() {
        response.send(message)
    }
 }
 
