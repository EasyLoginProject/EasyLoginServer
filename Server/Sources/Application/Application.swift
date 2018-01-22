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
import HeliumLogger
import SwiftyJSON
import Configuration
import CloudFoundryConfig
import CouchDB
import Extensions
import DataProvider
import EasyLoginDirectoryService
import NotificationService
import EasyLoginLDAPGatewayAPI
import EasyLoginAdminAPI
import SwiftMetrics
import SwiftMetricsDash

public enum ConfigError: Error {
    case missingDatabaseInfo
    case missingDatabaseName
}

public let manager = ConfigurationManager()
public let router = Router()
public let httpLogger = HTTPLogger()

public func initialize() throws {
    HeliumStreamLogger.use(.debug, outputStream: httpLogger)
    httpLogger.installHandler(to: router)
    
    manager.load(.commandLineArguments)
    if let configFile = manager["config"] as? String {
        manager.load(file:configFile)
    }
    manager.load(.environmentVariables)
           .load(.commandLineArguments) // always give precedence to CLI args
    
    let inspectorService = InspectorService()
    
    let mainDesignPath: String
    if let environmentVariable = getenv("RESOURCES"), let resourcePath = String(validatingUTF8: environmentVariable) {
        mainDesignPath = "\(resourcePath)/main_design.json"
    }
    else {
        mainDesignPath = "Resources/main_design.json"
    }
    
    var database: Database? = nil
    if let databaseDictionary = manager["database"] as? [String:Any] {
        guard let databaseName = databaseDictionary["name"] as? String else { throw ConfigError.missingDatabaseName }
        let couchDBClient = CouchDBClient(dictionary: databaseDictionary)
        Log.info("Connected to CouchDB, client = \(couchDBClient), database name = \(databaseName)")
        database = couchDBClient.createOrOpenDatabase(name: databaseName, designFile: mainDesignPath)
    }
    else if let cloudantService = try? manager.getCloudantService(name: "EasyLogin-Cloudant") {
        Log.debug("Trying to connect to Cloudant service at \(cloudantService.host):\(cloudantService.port) as \(cloudantService.username)")
        let databaseName = "easy_login"
        let couchDBClient = CouchDBClient(service: cloudantService)
        Log.info("Connected to Cloudant, client = \(couchDBClient), database name = \(databaseName)")
        database = couchDBClient.createOrOpenDatabase(name: databaseName, designFile: "Resources/main_design.json")
    }
    else {
        throw ConfigError.missingDatabaseInfo
    }
    
    if let database = database {
        let dataProvider = try DataProvider.singleton() // FIXME: provide database
        let directoryService = EasyLoginDirectoryService(database: database, dataProvider: dataProvider)
        router.all(middleware: EasyLoginAuthenticator(userProvider: database))
        router.all("/db", middleware: directoryService.router())
        
        let ldapGatewayAPI = try LDAPGatewayAPI()
        router.all("/ldap", middleware: ldapGatewayAPI.router())
        
        let adminAPI = try AdminAPI()
        router.all("/admapi", middleware: adminAPI.router())
        
        let notificationService = installNotificationService()
        inspectorService.registerInspectable(notificationService, name: "notifications")
        
        if let staticSettings = manager["static"] as? [String:Any] {
            // --static.admin=/Users/ygi/Sources/EasyLogin/EasyLoginWebAdmin/htdocs/admin
            if let staticAdminPath = staticSettings["admin"] as? String {
                router.all("/admin", middleware: StaticFileServer(path: staticAdminPath))
            }
        }
        
        // Enable SwiftMetrics Monitoring
        let sm = try SwiftMetrics()
        
        // Pass SwiftMetrics to the dashboard for visualising
        let _ = try SwiftMetricsDash(swiftMetricsInstance: sm, endpoint: router)

    }
    
    inspectorService.installHandlers(to: router)
}

public func installInitErrorRoute() {
    router.installInitErrorHandlers()
}

public func run() throws {
    Kitura.addHTTPServer(onPort: 8080, with: router)
    Kitura.run()
}
