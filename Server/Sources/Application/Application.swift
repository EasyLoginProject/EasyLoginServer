//
//  Application.swift
//  EasyLogin
//
//  Created by Frank on 17/05/17.
//
//

import Foundation
import Kitura
import LoggerAPI
import SwiftyJSON
import Configuration
import CloudFoundryConfig
import CouchDB

public enum ConfigError: Error {
    case missingDatabaseInfo
    case missingDatabaseName
}

public let manager = ConfigurationManager()
public let router = Router()

public var database: Database?

public func initialize() throws {
    manager.load(.commandLineArguments)
    if let configFile = manager["config"] as? String {
        manager.load(file:configFile)
    }
    manager.load(.environmentVariables)
           .load(.commandLineArguments) // always give precedence to CLI args
    if let databaseDictionary = manager["database"] as? [String:Any] {
        guard let databaseName = databaseDictionary["name"] as? String else { throw ConfigError.missingDatabaseName }
        let couchDBClient = CouchDBClient(dictionary: databaseDictionary)
        Log.info("Connected to CouchDB, client = \(couchDBClient), database name = \(databaseName)")
        database = couchDBClient.createOrOpenDatabase(name: databaseName, designFile: "../../Resources/main_design.json")
    }
    else if let cloudantService = try? manager.getCloudantService(name: "EasyLogin-Cloudant") {
        let databaseName = "easy_login"
        let couchDBClient = CouchDBClient(service: cloudantService)
        Log.info("Connected to Cloudant, client = \(couchDBClient), database name = \(databaseName)")
        database = couchDBClient.createOrOpenDatabase(name: databaseName, designFile: "Resources/main_design.json")
    }
    else {
        throw ConfigError.missingDatabaseInfo
    }
    
    router.post(middleware:BodyParser())
    router.put(middleware:BodyParser())
    
    router.installDatabaseUsersHandlers()
    router.installDatabaseDevicesHandlers()
    installNotificationService()
}

public func installInitErrorRoute() {
    router.installInitErrorHandlers()
}

public func run() throws {
    Kitura.addHTTPServer(onPort: 8080, with: router)
    Kitura.run()
}
