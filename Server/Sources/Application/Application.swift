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
import EasyLoginConfiguration
import CouchDB
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

public let router = Router()
public let httpLogger = HTTPLogger()

public func initialize() throws {
    HeliumStreamLogger.use(.debug, outputStream: httpLogger)
    httpLogger.installHandler(to: router)
    
    let inspectorService = InspectorService()
    
    let configurationManager = ConfigProvider.manager
    
    var couchDBClient: CouchDBClient?
    while couchDBClient == nil {
        do {
            couchDBClient = try CouchDBClient(configurationManager: configurationManager)
        }
        catch CouchDBClient.Error.configurationNotAvailable {
            throw ConfigError.missingDatabaseInfo
        }
        catch {
            couchDBClient = nil
            Log.info("CouchDB not available, retrying.")
            sleep(2)
        }
    }
    
    let databaseName = configurationManager.databaseName()
    let mainDesignPath = ConfigProvider.pathForResource("main_design.json")
    let database = couchDBClient!.createOrOpenDatabase(name: databaseName, designFile: mainDesignPath)
    
    Log.info("Connected to CouchDB, client = \(couchDBClient!), database name = \(databaseName)")
    
    let dataProvider = DataProvider(database: database)
    let directoryService = EasyLoginDirectoryService(database: database, dataProvider: dataProvider)
    router.all(middleware: EasyLoginAuthenticator(userProvider: database))
    router.all("/db", middleware: directoryService.router())
    
    let ldapGatewayAPI = LDAPGatewayAPI(dataProvider: dataProvider)
    router.all("/ldap", middleware: ldapGatewayAPI.router())
    
    let adminAPI = AdminAPI(dataProvider: dataProvider)
    router.all("/admapi", middleware: adminAPI.router())
    
    let notificationService = installNotificationService()
    inspectorService.registerInspectable(notificationService, name: "notifications")
    
    if let staticSettings = configurationManager["static"] as? [String:Any] {
        // --static.admin=/Users/ygi/Sources/EasyLogin/EasyLoginWebAdmin/htdocs/admin
        if let staticAdminPath = staticSettings["admin"] as? String {
            router.all("/admin", middleware: StaticFileServer(path: staticAdminPath))
        }
    }
    
    // Enable SwiftMetrics Monitoring
    let sm = try SwiftMetrics()
    
    // Pass SwiftMetrics to the dashboard for visualising
    let _ = try SwiftMetricsDash(swiftMetricsInstance: sm, endpoint: router)
    
    inspectorService.installHandlers(to: router)
}

public func installInitErrorRoute() {
    router.installInitErrorHandlers()
}

public func run() throws {
    Kitura.addHTTPServer(onPort: 8080, with: router)
    Kitura.run()
}

