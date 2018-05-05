//
//  Database+Bootstrap.swift
//  Application
//
//  Created by Frank on 19/04/2018.
//

import Foundation
import CouchDB
import KituraNet
import SwiftyJSON

extension Database {
    func applyMigration(_ migration: EasyLoginMigration) throws {
        guard let baseURL = migration.baseURL else {
            fatalError("missing baseURL in migration")
        }
        for step in migration.steps {
            try applyMigrationStep(step, withBaseURL: baseURL)
        }
    }
    
    func applyMigrationStep(_ step: EasyLoginMigrationStep, withBaseURL baseURL: URL) throws {
        switch step {
        case .create(let filename, let documentId):
            let fileURL = baseURL.appendingPathComponent(filename)
            try applyMigrationStep(create: documentId, withFile: fileURL)
        case .update(let filename, let documentId):
            let fileURL = baseURL.appendingPathComponent(filename)
            try applyMigrationStep(update: documentId, withFile: fileURL)
        case .delete(let documentId):
            try applyMigrationStep(delete: documentId)
        }
    }
    
    func applyMigrationStep(create documentId: String, withFile fileURL: URL) throws {
        var document = try JSON(data: Data(contentsOf: fileURL))
        document["_id"].stringValue = documentId
        let _: Bool = try Blocking.call {
            success, failure in
            self.create(document) {
                _, _, _, error in
                if let error = error {
                    failure(error)
                }
                else {
                    success(true)
                }
            }
        }
    }
    
    func applyMigrationStep(update documentId: String, withFile fileURL: URL) throws {
        var document = try JSON(data: Data(contentsOf: fileURL))
        let revision = try documentRevision(documentId: documentId)
        document["_rev"].stringValue = revision
        let _: Bool = try Blocking.call {
            success, failure in
            self.update(documentId, rev: revision, document: document) {
                _, _, error in
                if let error = error {
                    failure(error)
                }
                else {
                    success(true)
                }
            }
        }
    }
    
    func applyMigrationStep(delete documentId: String) throws {
        let revision = try documentRevision(documentId: documentId)
        let _: Bool = try Blocking.call {
            success, failure in
            self.delete(documentId, rev: revision) {
                error in
                if let error = error {
                    failure(error)
                }
                else {
                    success(true)
                }
            }
        }
    }
    
    func documentRevision(documentId: String) throws -> String {
        let document: JSON = try Blocking.call {
            success, failure in
            self.retrieve(documentId) {
                json, error in
                if let json = json {
                    success(json)
                }
                else {
                    failure(error!)
                }
            }
        }
        let revision = document["_rev"].stringValue
        return revision
    }
}

extension Database {
    static let databaseInfoDocumentId = "$database_description"
    static let databaseInfoType = "database_description"
    
    func retrieveInfo() throws -> DatabaseInfo? {
        let databaseInfo: JSON = try Blocking.call {
            success, failure in
            self.retrieve(Database.databaseInfoDocumentId) {
                json, error in
                if let error = error {
                    if error.code == HTTPStatusCode.notFound.rawValue {
                        success(nil)
                    }
                    else {
                        failure(error)
                    }
                }
                else {
                    success(json!)
                }
            }
        }
        guard databaseInfo != nil else {
            return nil
        }
        return try decodeInfo(json: databaseInfo)
    }
    
    func saveInfo(_ databaseInfo: DatabaseInfo) throws -> String {
        let json = try encodeInfo(databaseInfo)
        let newRevision: String = try Blocking.call {
            success, failure in
            if let currentRevision = databaseInfo.revision {
                self.update(Database.databaseInfoDocumentId, rev: currentRevision, document: json) {
                    revision, _, error in
                    if let revision = revision {
                        success(revision)
                    }
                    else {
                        failure(error!)
                    }
                }
            }
            else {
                self.create(json) {
                    _, revision, _, error in
                    if let revision = revision {
                        success(revision)
                    }
                    else {
                        failure(error!)
                    }
                }
            }
        }
        return newRevision
    }
    
    func decodeInfo(json: JSON) throws -> DatabaseInfo {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        let data = try json.rawData()
        let databaseInfo = try jsonDecoder.decode(DatabaseInfo.self, from: data)
        return databaseInfo
    }
    
    func encodeInfo(_ databaseInfo: DatabaseInfo) throws -> JSON {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        let data = try jsonEncoder.encode(databaseInfo)
        var json = JSON(data: data)
        json["_id"].stringValue = Database.databaseInfoDocumentId
        json["type"].stringValue = Database.databaseInfoType
        return json
    }
}
