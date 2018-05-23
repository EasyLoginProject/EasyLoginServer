//
//  PersistentCounter.swift
//  EasyLogin
//
//  Created by Frank on 29/06/17.
//
//

import Foundation
import KituraNet
import CouchDB
import SwiftyJSON
import LoggerAPI

public class PersistentCounter {
    let database: Database
    let documentID: String
    
    private enum ReadResult {
        case value(Int, String)
        case notFound
        case error(NSError)
    }
    
    public init(database: Database, name: String) {
        self.database = database
        documentID = "$counter/\(name)"
    }
    
    public func nextValue(completion: @escaping (Int?) -> Void) -> Void {
        readValue { (readResult) in
            switch readResult {
            case .value(let value, let revision):
                self.writeSuccessorAndReturnCurrentValue(value, revision: revision, completion: completion)
            case .notFound:
                Log.error("Error reading counter \(self.documentID) from database: not found")
                completion(nil)
            case .error(let error):
                Log.error("Error reading counter \(self.documentID) from database: \(error)")
                completion(nil)
            }
        }
    }
    
    private func writeSuccessorAndReturnCurrentValue(_ value: Int, revision: String, completion: @escaping (Int?) -> Void) -> Void {
        writeValue(value + 1, revision: revision) { (success) in
            if success {
                completion(value)
            }
            else {
                completion(nil)
            }
        }
    }
    
    private func readValue(completion: @escaping (ReadResult) -> Void) -> Void {
        Log.debug("Reading presistent counter \(documentID) from CouchDB")
        database.retrieve(documentID) { (document, error) in
            if let error = error {
                if error.domain == "CouchDBDomain" && error.code == HTTPStatusCode.notFound.rawValue {
                    completion(.notFound)
                }
                else {
                    completion(.error(error))
                }
                return
            }
            if let document = document,
            let revision = document["_rev"].string,
            let value = document["next"].int {
                completion(.value(value, revision))
                return
            }
        }
    }
    
    private func writeValue(_ value: Int, revision: String, completion: @escaping (Bool) -> Void) -> Void {
        let document = self.document(value)
        updateDocument(document, revision: revision, completion: completion)
    }
    
    private func updateDocument(_ document: JSON, revision: String, completion: @escaping (Bool) -> Void) -> Void {
        Log.debug("Updating presistent counter \(documentID) into CouchDB")
        database.update(documentID, rev: revision, document: document) { (revision, updatedDocument, error) in
            completion(updatedDocument != nil)
        }
    }
    
    private func document(_ value: Int) -> JSON {
        let dict: [String: Any] = ["_id": documentID, "type": "counter", "next": value]
        return JSON(dict)
    }
}
