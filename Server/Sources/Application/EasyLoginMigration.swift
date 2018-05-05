//
//  EasyLoginMigration.swift
//  Application
//
//  Created by Frank on 19/04/2018.
//

import Foundation

struct EasyLoginMigration: Decodable {
    var uuid: String
    var steps: [EasyLoginMigrationStep]
    var baseURL: URL?
}

enum EasyLoginMigrationStep: Decodable {
    case create(filename: String, documentId: String)
    case update(filename: String, documentId: String)
    case delete(documentId: String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let action = try container.decode(String.self, forKey: .action)
        switch action {
        case "create":
            let filename = try container.decode(String.self, forKey: .filename)
            let documentId = try container.decode(String.self, forKey: .documentId)
            self = .create(filename: filename, documentId: documentId)
        case "update":
            let filename = try container.decode(String.self, forKey: .filename)
            let documentId = try container.decode(String.self, forKey: .documentId)
            self = .update(filename: filename, documentId: documentId)
        case "delete":
            let documentId = try container.decode(String.self, forKey: .documentId)
            self = .delete(documentId: documentId)
        default:
            throw DecodingError.dataCorruptedError(forKey: .action, in: container, debugDescription: "Unsupported action: \(action)")
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case action
        case filename
        case documentId = "document_id"
    }
}
