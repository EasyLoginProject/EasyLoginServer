//
//  DataProvider.swift
//  EasyLogin
//
//  Created by Yoann Gini on 01/01/2018.
//

import Foundation
import CouchDB
import Kitura
import LoggerAPI
import SwiftyJSON
import Extensions

public struct CombinedError {
    let swiftError: Error?
    let cocoaError: NSError?
}

public enum DataProviderError: Error {
    case none
    case missingDatabaseInfo
    case singletonMissing
}

public class DataProvider {
    private let couchDBClient: CouchDBClient
    private let database: Database
    
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
        
        database = couchDBClient.createOrOpenDatabase(name: databaseName, designFile: ConfigProvider.pathForRessource("main_design.json"))
        Log.info("Connected to CouchDB, client = \(couchDBClient), database name = \(databaseName)")
    }
    
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
    
    public func managedObject<T: ManagedObject>(ofType:T.Type, withUUID uuid:String, completion: @escaping (T?, CombinedError?) -> Void) -> Void {
        jsonData(forRecordWithID: uuid) { (jsonData, jsonError) in
            if let jsonData = jsonData {
                do {
                    let managedObject = try T.objectFromJSON(data: jsonData, withCodingStrategy: .databaseEncoding)
                    completion(managedObject, nil)
                } catch {
                    completion(nil, CombinedError(swiftError: error, cocoaError: nil))
                }
            } else {
                completion(nil, CombinedError(swiftError: nil, cocoaError: jsonError))
            }
        }
    }
    
    public func managedObject<T: ManagedObject>(fromPartialManagedObject managedObject:T, completion: @escaping (T?, CombinedError?) -> Void) -> Void {
        if managedObject.isPartialRepresentation {
            jsonData(forRecordWithID: managedObject.uuid) { (jsonData, jsonError) in
                if let jsonData = jsonData {
                    do {
                        let managedObject = try T.objectFromJSON(data: jsonData, withCodingStrategy: .databaseEncoding)
                        completion(managedObject, nil)
                    } catch {
                        completion(nil, CombinedError(swiftError: error, cocoaError: nil))
                    }
                } else {
                    completion(nil, CombinedError(swiftError: nil, cocoaError: jsonError))
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
                    let strategy: ManagedObjectCodingStrategy = T.viewToListThemAllReturnPartialResult() ? .briefEncoding : .databaseEncoding
                    let jsonDecoder = JSONDecoder()
                    jsonDecoder.userInfo[.managedObjectCodingStrategy] = strategy
                    let viewResults = try jsonDecoder.decode(CouchDBViewResult<T>.self, from: jsonData)
                    
                    let managedObjects = viewResults.rows.map({ (couchDBView) -> T in
                        return couchDBView.value
                    })
                    
                    completion(managedObjects, nil)
                } catch {
                    completion(nil, CombinedError(swiftError: error, cocoaError: nil))
                }
            } else {
                completion(nil, CombinedError(swiftError: nil, cocoaError: jsonError))
            }
        }
    }
    
    public func managedUser(withLogin login:String, completion: @escaping (ManagedUser?, CombinedError?) -> Void) {
        if login.contains("@") {
            jsonData(fromView: "user_brief_by_principalName", ofDesign: "main_design", usingParameters: [.keys([login as AnyObject])], completion: { (jsonData, jsonError) in
                if let jsonData = jsonData {
                    do {
                        let jsonDecoder = JSONDecoder()
                        jsonDecoder.userInfo[.managedObjectCodingStrategy] = ManagedObjectCodingStrategy.briefEncoding
                        let viewResults = try jsonDecoder.decode(CouchDBViewResult<ManagedUser>.self, from: jsonData)
                        
                        if viewResults.rows.count != 1 {
                            completion(nil, nil)
                        } else {
                            completion(viewResults.rows.first?.value, nil)
                        }
                    } catch {
                        completion(nil, CombinedError(swiftError: error, cocoaError: nil))
                    }
                } else {
                    completion(nil, CombinedError(swiftError: nil, cocoaError: jsonError))
                }
            })
        } else {
            jsonData(fromView: "user_brief_by_shortname", ofDesign: "main_design", usingParameters: [.keys([login as AnyObject])], completion: { (jsonData, jsonError) in
                if let jsonData = jsonData {
                    do {
                        let jsonDecoder = JSONDecoder()
                        jsonDecoder.userInfo[.managedObjectCodingStrategy] = ManagedObjectCodingStrategy.briefEncoding
                        let viewResults = try jsonDecoder.decode(CouchDBViewResult<ManagedUser>.self, from: jsonData)
                        
                        if viewResults.rows.count != 1 {
                            completion(nil, nil)
                        } else {
                            completion(viewResults.rows.first?.value, nil)
                        }
                    } catch {
                        completion(nil, CombinedError(swiftError: error, cocoaError: nil))
                    }
                } else {
                    completion(nil, CombinedError(swiftError: nil, cocoaError: jsonError))
                }
            })
        }
    }
}


