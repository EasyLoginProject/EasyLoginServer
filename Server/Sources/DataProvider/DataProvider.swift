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
    case missingDatabaseInfo
    case singletonMissing
    case tryingToUpdateNonExistingObject
}

public class DataProvider {
    private let couchDBClient: CouchDBClient
    private let database: Database
    public let numericIDGenerator: PersistentCounter
    
    static private var privateSingleton: DataProvider?
    public static func singleton() throws -> DataProvider {
        guard let existigSingleton = privateSingleton else {
            privateSingleton = try DataProvider()
            return privateSingleton!
        }
        return existigSingleton
    }
    
    private init() throws {
        var databaseName = "easy_login"
        if let dictionary = ConfigProvider.manager["database"] as? [String:Any] {
            // When manual database settings has been provided, we use them
            
            databaseName = dictionary["name"] as? String ?? "easylogin"
            
            let host = dictionary["host"] as? String ?? "127.0.0.1"
            let port = dictionary["port"] as? Int16 ?? 5984
            let username = dictionary["username"] as? String
            let password = dictionary["password"] as? String
            let secured = dictionary["secured"] as? Bool ?? false
            
            let connProperties = ConnectionProperties(host: host,
                                                      port: port,
                                                      secured: secured,
                                                      username: username,
                                                      password: password)
            
            Log.debug("Using manual plus default settings, CouchDB info \(connProperties)")
            couchDBClient = CouchDBClient(connectionProperties: connProperties)
        }
        else if let cloudantService = try? ConfigProvider.manager.getCloudantService(name: "EasyLogin-Cloudant") {
            // If not manual config is here and if we found a CloudFoundry based settings, we use them
            
            Log.debug("Using CloudFroundry based information, CouchDB at \(cloudantService.host):\(cloudantService.port) as \(cloudantService.username)")
            couchDBClient = CouchDBClient(service: cloudantService)
        } else {
            throw DataProviderError.missingDatabaseInfo
        }
        
        database = couchDBClient.createOrOpenDatabase(name: databaseName, designFile: ConfigProvider.pathForResource("main_design.json"))
        numericIDGenerator = PersistentCounter(database: database, name: "users.numericID", initialValue: 1789)
        Log.info("Connected to CouchDB, client = \(couchDBClient), database name = \(databaseName)")
        
    }
    
    // MARK: Database SPI
    
    private func jsonData(forRecordWithID recordID: String, completion: @escaping (Data?, NSError?) -> Void) {
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
    
    private func update(recordID: String, atRev rev:String, with jsonData:Data, completion: @escaping (String?, Data?, NSError?) -> Void) {
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
    
    public func completeManagedObject<T: ManagedObject>(ofType:T.Type, withUUID uuid:String, completion: @escaping (T?, CombinedError?) -> Void) -> Void {
        jsonData(forRecordWithID: uuid) { (jsonData, jsonError) in
            if let jsonData = jsonData {
                do {
                    let managedObject = try T.objectFromJSON(data: jsonData, withCodingStrategy: .databaseEncoding)
                    completion(managedObject, nil)
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else {
                completion(nil, .cocoaError(jsonError ?? NSError()))
            }
        }
    }
    
    public func completeManagedObjects<T: ManagedObject>(ofType:T.Type, withUUIDs uuids:[String], completion: @escaping ([String:T], CombinedError?) -> Void) -> Void {
        guard uuids.count != 0 else {
            completion([:], nil)
            return
        }
        var result: [String:T] = [:]
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
                else {
                    lastError = .cocoaError(jsonError ?? NSError())
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
                } else {
                    completion(nil, .cocoaError(jsonError ?? NSError()))
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
                    jsonDecoder.userInfo[.managedObjectCodingStrategy] = strategy
                    let viewResults = try jsonDecoder.decode(CouchDBViewResult<T>.self, from: jsonData)
                    
                    let managedObjects = viewResults.rows.map({ (couchDBView) -> T in
                        return couchDBView.value
                    })
                    
                    completion(managedObjects, nil)
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else {
                completion(nil, .cocoaError(jsonError ?? NSError()))
            }
        }
    }
    
    public func completeManagedObjects<T: ManagedObject>(ofType:T.Type, completion: @escaping ([T]?, CombinedError?) -> Void) -> Void {
        jsonData(fromView: T.viewToListThemAll(), ofDesign: T.designFile(), usingParameters: [.includeDocs(true)]) { (jsonData, jsonError) in
            if let jsonData = jsonData {
                do {
                    let strategy: ManagedObjectCodingStrategy = .databaseEncoding
                    let jsonDecoder = JSONDecoder()
                    jsonDecoder.userInfo[.managedObjectCodingStrategy] = strategy
                    let viewResults = try jsonDecoder.decode(CouchDBViewResult<T>.self, from: jsonData)
                    
                    let managedObjects = viewResults.rows.map({ (couchDBView) -> T in
                        return couchDBView.value
                    })
                    
                    completion(managedObjects, nil)
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else {
                completion(nil, .cocoaError(jsonError ?? NSError()))
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
            } else {
                completion(nil, .cocoaError(jsonError ?? NSError()))
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
            } else {
                completion(nil, .cocoaError(jsonError ?? NSError()))
            }
        })
    }
    
    public func storeChangeFrom<T: ManagedObject>(mutableManagedObject:T, completion: @escaping (T?, CombinedError?) -> Void) throws  where T: MutableManagedObject {
        guard mutableManagedObject.hasBeenEdited == true else {
            completion(mutableManagedObject, nil)
            return
        }
        
        guard let revision = mutableManagedObject.revision else {
            throw DataProviderError.tryingToUpdateNonExistingObject
        }
        
        let jsonData = try mutableManagedObject.jsonData(withCodingStrategy: .databaseEncoding)
        
        update(recordID: mutableManagedObject.uuid, atRev: revision, with: jsonData) { (revision, updatedJSONData, error) in
            if let updatedJSONData = updatedJSONData {
                do {
                    let updateResult = try JSONDecoder().decode(CouchDBUpdateResult.self, from: updatedJSONData)
                    
                    if updateResult.ok {
                        self.completeManagedObject(ofType: T.self, withUUID: updateResult.id, completion: completion)
                        NotificationService.notifyAllClients()
                    } else {
                        completion(nil, .cocoaError(error ?? NSError()))
                    }
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else {
                completion(nil, .cocoaError(error ?? NSError()))
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
            do {
                try storeChangeFrom(mutableManagedObject: mutableManagedObject) {
                    (updatedManagedObject, error) in
                    if let updatedManagedObject = updatedManagedObject {
                        result.append(updatedManagedObject)
                    }
                    else {
                        lastError = error ?? .cocoaError(NSError()) // TODO: result type
                    }
                }
            }
            catch {
                lastError = .swiftError(error)
            }
            remainingCount.signal()
        }
        DispatchQueue.global().async {
            remainingCount.wait()
            completion(result, lastError)
        }
    }
    
    public func insert<T: ManagedObject>(mutableManagedObject:T, completion: @escaping (T?, CombinedError?) -> Void) throws  where T: MutableManagedObject {
        guard mutableManagedObject.hasBeenEdited == true else {
            completion(mutableManagedObject, nil)
            return
        }
        
        let jsonData = try mutableManagedObject.jsonData(withCodingStrategy: .databaseEncoding)
        
        create(recordWithJSONData: jsonData) { (jsonData, error) in
            if let jsonData = jsonData {
                do {
                    let updateResult = try JSONDecoder().decode(CouchDBUpdateResult.self, from: jsonData)
                    
                    if updateResult.ok {
                        self.completeManagedObject(ofType: T.self, withUUID: updateResult.id, completion: completion)
                        NotificationService.notifyAllClients()
                    } else {
                        completion(nil, .cocoaError(error ?? NSError()))
                    }
                } catch {
                    completion(nil, .swiftError(error))
                }
            } else {
                completion(nil, .cocoaError(error ?? NSError()))
            }
        }
    }
    
    public func delete<T: ManagedObject>(managedObject:T, completion: @escaping (CombinedError?) -> Void) throws {
        guard let revision = managedObject.revision else {
            throw DataProviderError.tryingToUpdateNonExistingObject
        }
        
        managedObject.markAsDeleted()
        let jsonData = try managedObject.jsonData(withCodingStrategy: .databaseEncoding)
        
        update(recordID: managedObject.uuid, atRev: revision, with: jsonData) { (revision, updatedJSONData, error) in
            if let updatedJSONData = updatedJSONData {
                do {
                    let updateResult = try JSONDecoder().decode(CouchDBUpdateResult.self, from: updatedJSONData)
                    
                    if updateResult.ok {
                        completion(nil)
                        NotificationService.notifyAllClients()
                    } else {
                        completion(.cocoaError(error ?? NSError()))
                    }
                } catch {
                    completion(.swiftError(error))
                }
            } else {
                completion(.cocoaError(error ?? NSError()))
            }
        }
    }
}


