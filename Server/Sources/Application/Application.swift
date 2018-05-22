//
//  Application.swift
//  EasyLogin
//
//  Created by Frank on 17/05/17.
//
//

import Foundation
import Dispatch
import Kitura
import LoggerAPI
import HeliumLogger
import Configuration
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

let serviceEnablerQueue = DispatchQueue(label: "serviceEnabler")

public func initialize() throws {
    let httpLogger = HTTPLogger()
    HeliumStreamLogger.use(.debug, outputStream: httpLogger)
    httpLogger.installHandler(to: router)
    
    let inspectorService = InspectorService()
    
    let configurationManager = ConfigProvider.manager
    let migrationDirectoryPath = ConfigProvider.pathForResource("migrations")
    let expectedMigrations = try getAvailableMigrations(inDirectory: migrationDirectoryPath).map {$0.uuid}
    
    let serviceEnabler = EasyLoginServiceEnabler()
    router.all(middleware: serviceEnabler)
    
    guard startDataProviderStack(configurationManager: configurationManager, expectedMigrations: expectedMigrations, completion: {
        database in
        serviceEnablerQueue.async() {
            serviceEnabler.start(withDatabase: database)
        }
    }) else {
        throw ConfigError.missingDatabaseInfo
    }
    
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

func startDataProviderStack(configurationManager: ConfigurationManager, expectedMigrations: [String], completion: @escaping (Database) -> Void) -> Bool {
    do {
        let couchDBClient = try CouchDBClient(configurationManager: configurationManager)
        let databaseName = configurationManager.databaseName()
        Log.info("Connected to CouchDB, client = \(couchDBClient), database name = \(databaseName)")
        openDatabaseAsync(couchDBClient: couchDBClient, databaseName: databaseName, expectedMigrations: expectedMigrations, completion: completion)
    }
    catch CouchDBClient.Error.configurationNotAvailable {
        Log.error("CouchDB configuration not found.")
        return false
    }
    catch {
        Log.info("CouchDB not available, retrying.")
        serviceEnablerQueue.asyncAfter(deadline: .now() + .seconds(2)) {
            _ = startDataProviderStack(configurationManager: configurationManager, expectedMigrations: expectedMigrations, completion: completion)
        }
    }
    return true
}

func openDatabaseAsync(couchDBClient: CouchDBClient, databaseName: String, expectedMigrations: [String], completion: @escaping (Database) -> Void) {
    couchDBClient.dbExists(databaseName) {
        exists, error in
        if exists {
            Log.info("Database found.")
            let database = couchDBClient.database(databaseName)
            verifyMigrations(database: database, expectedMigrations: expectedMigrations, completion: completion)
        }
        else {
            Log.info("Database not found, retrying.")
            serviceEnablerQueue.asyncAfter(deadline: .now() + .seconds(2)) {
                openDatabaseAsync(couchDBClient: couchDBClient, databaseName: databaseName, expectedMigrations: expectedMigrations, completion: completion)
            }
        }
    }
}

func verifyMigrations(database: Database, expectedMigrations: [String], completion: @escaping (Database) -> Void) {
    database.retrieve(Database.databaseInfoDocumentId) {
        json, error in
        if let json = json, let databaseInfo = try? database.decodeInfo(json: json) {
            let appliedMigrations = databaseInfo.migrations.map {$0.uuid}
            if Set(appliedMigrations) == Set(expectedMigrations) {
                Log.info("Database up-to-date.")
                completion(database)
                return
            }
            // FIXME: abort if applied migrations are more recent than expected migrations (wait for application upgrade).
        }
        Log.info("Database migration mismatch, retrying.")
        serviceEnablerQueue.asyncAfter(deadline: .now() + .seconds(2)) {
            verifyMigrations(database: database, expectedMigrations: expectedMigrations, completion: completion)
        }
    }
}
