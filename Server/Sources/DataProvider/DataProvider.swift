//
//  DataProvider.swift
//  EasyLogin
//
//  Created by Yoann Gini on 01/01/2018.
//

import Foundation
import Dispatch
import CouchDB
import Kitura
import LoggerAPI
import SwiftyJSON
import Extensions
import NotificationService

public enum CombinedError {
    case swiftError(Error)
    case cocoaError(NSError)
}

public enum DataProviderError: Error {
    case none
    case tryingToUpdateNonExistingObject
}

public class DataProvider {
    private let database: Database
    private var persistentCounters: [String: PersistentCounter]
    
    public init(database: Database) {
        self.database = database
        self.persistentCounters = [:]
    }
    
    public func persistentCounter(name: String) -> PersistentCounter {
        if let persistentCounter = persistentCounters[name] {
            return persistentCounter
        }
        let persistentCounter = PersistentCounter(database: database, name: name, initialValue: 1789) // TODO: initial value for each counter will be set by bootstrap application
        persistentCounters[name] = persistentCounter
        return persistentCounter
    }
    
    // MARK: Database SPI
    
    private func jsonData(forRecordWithID recordID: ManagedObjectRecordID, completion: @escaping (Data?, NSError?) -> Void) {
        database.retrieve(recordID, callback: { (document: JSON?, error: NSError?) in
            guard let document = document else {
                completion(nil, error)
                return
            }
            
            let jsonData = try? document.rawData()
            completion(jsonData, nil)
        })
    }
    
    private func jsonData(fromView view:String, ofDesign design:String, usingParameters params: [Database.QueryParameters], completion: @escaping (Data?, NSError?) -> Void) {
        database.queryByView(view, ofDesign: design, usingParameters:params) { (databaseResponse, error) in
            guard let databaseResponse = databaseResponse else {
                completion(nil, error)
                return
            }
            
            let jsonData = try? databaseResponse.rawData()
            completion(jsonData, nil)
        }
    }
    
    private func update(recordID: ManagedObjectRecordID, atRev rev:String, with jsonData:Data, completion: @escaping (String?, Data?, NSError?) -> Void) {
        let document = JSON(data:jsonData)
        database.update(recordID, rev: rev, document: document) { (rev, updatedDocument, error) in
            if let updatedDocument = updatedDocument {
                let jsonData = try? updatedDocument.rawData()
                completion(rev, jsonData, error)
            } else {
                completion(rev, nil, error)
            }
        }
    }
    
    private func create(recordWithJSONData jsonData:Data, completion: @escaping (Data?, NSError?) -> Void) {
        let document = JSON(data:jsonData)
        database.create(document) { (id, revision, document, error) in
            if let document = document {
                let jsonData = try? document.rawData()
                completion(jsonData, error)
            } else {
                completion(nil, error)
            }
        }
    }
    
    // MARK: Managed Object API
    
    public func completeManagedObject<T: ManagedObject>(ofType:T.Type, withUUID uuid:ManagedObjectRecordID, completion: @escaping (T?, CombinedError?) -> Void) -> Void {
        jsonData(forRecordWithID: uuid) { (jsonData, jsonError) in
            if let jsonData = jsonData {
                do {
                    let managedObject = try T.objectFromJSON(data: jsonData, withCodingStrategy: .databaseEncoding)
                    completion(managedObject, nil)
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else if let jsonError = jsonError {
                completion(nil, .cocoaError(jsonError))
            }
            else {
                completion(nil, .swiftError(DataProviderError.none))
            }
        }
    }
    
    public func completeManagedObjects<T: ManagedObject>(ofType:T.Type, withUUIDs uuids:[ManagedObjectRecordID], completion: @escaping ([ManagedObjectRecordID:T], CombinedError?) -> Void) -> Void {
        guard uuids.count != 0 else {
            completion([:], nil)
            return
        }
        var result: [ManagedObjectRecordID:T] = [:]
        let remainingCount = DispatchSemaphore(value: uuids.count)
        var lastError: CombinedError? = nil
        for uuid in uuids {
            jsonData(forRecordWithID: uuid) {
                (jsonData, jsonError) in
                if let jsonData = jsonData {
                    do {
                        let managedObject = try T.objectFromJSON(data: jsonData, withCodingStrategy: .databaseEncoding)
                        result[uuid] = managedObject
                    }
                    catch {
                        lastError = .swiftError(error)
                    }
                }
                else if let jsonError = jsonError {
                    lastError = .cocoaError(jsonError)
                }
                else {
                    lastError = .swiftError(DataProviderError.none)
                }
                remainingCount.signal()
            }
        }
        DispatchQueue.global().async {
            remainingCount.wait()
            completion(result, lastError)
        }
    }
    
    public func completeManagedObject<T: ManagedObject>(fromPartialManagedObject managedObject:T, completion: @escaping (T?, CombinedError?) -> Void) -> Void {
        if managedObject.isPartialRepresentation {
            jsonData(forRecordWithID: managedObject.uuid) { (jsonData, jsonError) in
                if let jsonData = jsonData {
                    do {
                        let managedObject = try T.objectFromJSON(data: jsonData, withCodingStrategy: .databaseEncoding)
                        completion(managedObject, nil)
                    } catch {
                        completion(nil, .swiftError(error))
                    }
                } else if let jsonError = jsonError {
                    completion(nil, .cocoaError(jsonError))
                }
                else {
                    completion(nil, .swiftError(DataProviderError.none))
                }
            }
        } else {
            completion(managedObject, nil)
        }
    }
    
    public func managedObjects<T: ManagedObject>(ofType:T.Type, completion: @escaping ([T]?, CombinedError?) -> Void) -> Void {
        jsonData(fromView: T.viewToListThemAll(), ofDesign: T.designFile(), usingParameters: []) { (jsonData, jsonError) in
            if let jsonData = jsonData {
                do {
                    let strategy: ManagedObjectCodingStrategy = T.requireFullObject() ? .databaseEncoding : T.viewToListThemAllReturnPartialResult() ? .briefEncoding : .databaseEncoding
                    let jsonDecoder = JSONDecoder()
                    jsonDecoder.dateDecodingStrategy = .iso8601
                    jsonDecoder.userInfo[.managedObjectCodingStrategy] = strategy
                    let viewResults = try jsonDecoder.decode(CouchDBViewResult<T>.self, from: jsonData)
                    
                    let managedObjects = viewResults.rows.map({ (couchDBView) -> T in
                        return couchDBView.value
                    })
                    
                    completion(managedObjects, nil)
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else if let jsonError = jsonError {
                completion(nil, .cocoaError(jsonError))
            }
            else {
                completion(nil, .swiftError(DataProviderError.none))
            }
        }
    }
    
    public func completeManagedObjects<T: ManagedObject>(ofType:T.Type, completion: @escaping ([T]?, CombinedError?) -> Void) -> Void {
        jsonData(fromView: T.viewToListThemAll(), ofDesign: T.designFile(), usingParameters: [.includeDocs(true)]) { (jsonData, jsonError) in
            if let jsonData = jsonData {
                do {
                    let strategy: ManagedObjectCodingStrategy = .databaseEncoding
                    let jsonDecoder = JSONDecoder()
                    jsonDecoder.dateDecodingStrategy = .iso8601
                    jsonDecoder.userInfo[.managedObjectCodingStrategy] = strategy
                    let viewResults = try jsonDecoder.decode(CouchDBViewResult<T>.self, from: jsonData)
                    
                    let managedObjects = viewResults.rows.map({ (couchDBView) -> T in
                        return couchDBView.value
                    })
                    
                    completion(managedObjects, nil)
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else if let jsonError = jsonError {
                completion(nil, .cocoaError(jsonError))
            }
            else {
                completion(nil, .swiftError(DataProviderError.none))
            }
        }
    }
    
    public func managedUser(withLogin login:String, completion: @escaping (ManagedUser?, CombinedError?) -> Void) {
        let guessedView: String
        if login.contains("@") {
            guessedView = "user_brief_by_principalName"
        } else {
            guessedView = "user_brief_by_shortname"
        }
        jsonData(fromView: guessedView, ofDesign: "main_design", usingParameters: [.keys([login as Database.KeyType])], completion: { (jsonData, jsonError) in
            if let jsonData = jsonData {
                do {
                    let viewResults = try CouchDBViewResult<ManagedUser>.objectFromJSON(data: jsonData, withCodingStrategy: ManagedObjectCodingStrategy.briefEncoding)
                    if viewResults.rows.count != 1 {
                        completion(nil, nil)
                    } else {
                        completion(viewResults.rows.first?.value, nil)
                    }
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else if let jsonError = jsonError {
                completion(nil, .cocoaError(jsonError))
            }
            else {
                completion(nil, .swiftError(DataProviderError.none))
            }
        })
    }
    
    public func completeManagedUser(withLogin login:String, completion: @escaping (ManagedUser?, CombinedError?) -> Void) {
        let guessedView: String
        if login.contains("@") {
            guessedView = "user_brief_by_principalName"
        } else {
            guessedView = "user_brief_by_shortname"
        }
        jsonData(fromView: guessedView, ofDesign: "main_design", usingParameters: [.keys([login as Database.KeyType]), .includeDocs(true)], completion: { (jsonData, jsonError) in
            if let jsonData = jsonData {
                do {
                    let viewResults = try CouchDBViewResult<ManagedUser>.objectFromJSON(data: jsonData, withCodingStrategy: ManagedObjectCodingStrategy.databaseEncoding)
                    if viewResults.rows.count != 1 {
                        completion(nil, nil)
                    } else {
                        completion(viewResults.rows.first?.value, nil)
                    }
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else if let jsonError = jsonError {
                completion(nil, .cocoaError(jsonError))
            }
            else {
                completion(nil, .swiftError(DataProviderError.none))
            }
        })
    }
    
    public func storeChangeFrom<T: ManagedObject>(mutableManagedObject:T, completion: @escaping (T?, CombinedError?) -> Void) where T: MutableManagedObject {
        guard mutableManagedObject.hasBeenEdited == true else {
            completion(mutableManagedObject, nil)
            return
        }
        
        guard let revision = mutableManagedObject.revision else {
            completion(nil, .swiftError(DataProviderError.tryingToUpdateNonExistingObject))
            return
        }
        
        mutableManagedObject.markAsModified()
        
        let jsonData: Data
        do {
            jsonData = try mutableManagedObject.jsonData()
        }
        catch {
            completion(nil, .swiftError(error))
            return
        }
        
        update(recordID: mutableManagedObject.uuid, atRev: revision, with: jsonData) { (revision, updatedJSONData, error) in
            if let updatedJSONData = updatedJSONData {
                do {
                    let updateResult = try JSONDecoder().decode(CouchDBUpdateResult.self, from: updatedJSONData)
                    
                    if updateResult.ok {
                        self.completeManagedObject(ofType: T.self, withUUID: updateResult.id, completion: completion)
                        NotificationService.notifyAllClients()
                    } else if let error = error {
                        completion(nil, .cocoaError(error))
                    }
                    else {
                        completion(nil, .swiftError(DataProviderError.none))
                    }
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else if let error = error {
                completion(nil, .cocoaError(error))
            }
            else {
                completion(nil, .swiftError(DataProviderError.none))
            }
        }
    }
    
    public func storeChangesFrom<T: ManagedObject>(mutableManagedObjects:[T], completion: @escaping ([T], CombinedError?) -> Void) where T: MutableManagedObject {
        guard mutableManagedObjects.count != 0 else {
            completion([], nil)
            return
        }
        var result: [T] = []
        let remainingCount = DispatchSemaphore(value: mutableManagedObjects.count)
        var lastError: CombinedError? = nil
        for mutableManagedObject in mutableManagedObjects {
            storeChangeFrom(mutableManagedObject: mutableManagedObject) {
                (updatedManagedObject, error) in
                if let updatedManagedObject = updatedManagedObject {
                    result.append(updatedManagedObject)
                }
                else {
                    lastError = error ?? .swiftError(DataProviderError.none)
                }
            }
            remainingCount.signal()
        }
        DispatchQueue.global().async {
            remainingCount.wait()
            completion(result, lastError)
        }
    }
    
    public func insert<T: ManagedObject>(mutableManagedObject:T, completion: @escaping (T?, CombinedError?) -> Void) where T: MutableManagedObject {
        guard mutableManagedObject.hasBeenEdited == true else {
            completion(mutableManagedObject, nil)
            return
        }
        
        let jsonData: Data
        do {
            jsonData = try mutableManagedObject.jsonData()
        }
        catch {
            completion(nil, .swiftError(error))
            return
        }
        
        create(recordWithJSONData: jsonData) { (jsonData, error) in
            if let jsonData = jsonData {
                do {
                    let updateResult = try JSONDecoder().decode(CouchDBUpdateResult.self, from: jsonData)
                    
                    if updateResult.ok {
                        self.completeManagedObject(ofType: T.self, withUUID: updateResult.id, completion: completion)
                        NotificationService.notifyAllClients()
                    } else if let error = error {
                        completion(nil, .cocoaError(error))
                    }
                    else {
                        completion(nil, .swiftError(DataProviderError.none))
                    }
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else if let error = error {
                completion(nil, .cocoaError(error))
            }
            else {
                completion(nil, .swiftError(DataProviderError.none))
            }
        }
    }
    
    public func delete<T: ManagedObject>(managedObject:T, completion: @escaping (CombinedError?) -> Void) {
        guard let revision = managedObject.revision else {
            completion(.swiftError(DataProviderError.tryingToUpdateNonExistingObject))
            return
        }
        
        managedObject.markAsDeleted()
        let jsonData: Data
        do {
            jsonData = try managedObject.jsonData()
        }
        catch {
            completion(.swiftError(error))
            return
        }
        
        update(recordID: managedObject.uuid, atRev: revision, with: jsonData) { (revision, updatedJSONData, error) in
            if let updatedJSONData = updatedJSONData {
                do {
                    let updateResult = try JSONDecoder().decode(CouchDBUpdateResult.self, from: updatedJSONData)
                    
                    if updateResult.ok {
                        completion(nil)
                        NotificationService.notifyAllClients()
                    } else if let error = error {
                        completion(.cocoaError(error))
                    }
                    else {
                        completion(.swiftError(DataProviderError.none))
                    }
                } catch {
                    completion(.swiftError(error))
                }
            } else if let error = error {
                completion(.cocoaError(error))
            }
            else {
                completion(.swiftError(DataProviderError.none))
            }
        }
    }
}


