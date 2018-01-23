import Foundation
import CouchDB
import Configuration
import CloudFoundryConfig
import SwiftyJSON
import LoggerAPI

public extension CouchDBClient {

    public enum Error: Swift.Error {
        case configurationNotAvailable
        case databaseNotFound
        case resourceNotFound
    }
    
    public convenience init(configurationManager: ConfigurationManager) throws {
        if let dictionary = configurationManager.getManualConfiguration() {
            // When manual database settings have been provided, we use them
            self.init(dictionary: dictionary)
        }
        else if let cloudantService = configurationManager.getCloudantConfiguration() {
            // If no manual config is provided and if we found CloudFoundry based settings, we use them
            self.init(service: cloudantService)
        }
        else {
            throw Error.configurationNotAvailable
        }
    }
    
    public convenience init(service: CloudantService) {
        
        let connProperties = ConnectionProperties(host: service.host,
                                                  port: Int16(service.port),
                                                  secured: true,
                                                  username: service.username,
                                                  password: service.password)
        
        Log.debug("Initializing CouchDBClient with CloudFoundry information: \(connProperties)")
        self.init(connectionProperties: connProperties)
    }
    
    public convenience init(dictionary: [String:Any]) {
        
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
        
        Log.debug("Initializing CouchDBClient with manual/default configuration \(connProperties)")
        self.init(connectionProperties: connProperties)
    }
    
    public func createOrOpenDatabase(name: String, designFile: String) -> Database {
        self.dbExists(name) {
            exists, error in
            if !exists {
                if let error = error {
                    Log.error("error on dbExists: \(error.localizedDescription)")
                }
                self.createDB(name) {
                    database, error in
                    guard let database = database else {
                        let errorMessage = error?.localizedDescription ?? "error == nil"
                        Log.error("cannot create database: \(errorMessage)")
                        return
                    }
                    guard let json = try? String(contentsOfFile: designFile, encoding:.utf8) else {
                        Log.error("cannot load file \(designFile)")
                        return
                    }
                    let document = JSON.parse(string: json)
                    database.createDesign("main_design", document: document) { (result, error) in
                        Log.info("database index creation: \(String(describing: result))")
                    }
                }
            }
            else {
                let database = self.database(name)
                guard let json = try? String(contentsOfFile: designFile, encoding:.utf8) else {
                    Log.error("cannot load file \(designFile)")
                    return
                }
                let document = JSON.parse(string: json)
                self.updateDesignDocument(database: database, document: document)
            }
        }
        return self.database(name)
    }
    
    func updateDesignDocument(database: Database, document: JSON) {
        database.retrieve("_design/main_design") { (oldDocument, error) in
            guard let oldDocument = oldDocument else { return }
            guard let rev = oldDocument["_rev"].string else { return }
            database.update("_design/main_design", rev: rev, document: document, callback: { (_, _, error) in
                if error == nil {
                    Log.info("Design document updated")
                }
            })
        }
    }
}
