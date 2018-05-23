//
//  Bootstrap.swift
//  Application
//
//  Created by Frank on 21/02/2018.
//

import Foundation
import Kitura
import LoggerAPI
import HeliumLogger
import Configuration
import EasyLoginConfiguration
import CouchDB

public enum BootstrapError: Error {
    case invalidConfiguration
    case databaseEngineNotResponding
    case databaseCreationFailure(Error?)
}

func databaseConnection(configurationManager: ConfigurationManager) throws -> CouchDBClient {
    do {
        let couchDBClient = try CouchDBClient(configurationManager: configurationManager)
        return couchDBClient
    }
    catch CouchDBClient.Error.configurationNotAvailable {
        throw BootstrapError.invalidConfiguration
    }
    catch {
        throw BootstrapError.databaseEngineNotResponding
    }
}

func openDatabase(configurationManager: ConfigurationManager) throws -> Database {
    let couchDBClient = try databaseConnection(configurationManager: configurationManager)
    let databaseName = configurationManager.databaseName()
    let database: Database = try Blocking.call {
        success, failure in
        couchDBClient.dbExists(databaseName) {
            exists, error in
            if exists {
                let database = couchDBClient.database(databaseName)
                success(database)
            }
            else {
                couchDBClient.createDB(databaseName) {
                    database, error in
                    if let database = database {
                        success(database)
                    }
                    else {
                        failure(BootstrapError.databaseCreationFailure(error))
                    }
                }
            }
        }
    }
    return database
}

func getAvailableMigrations(inDirectory migrationDirectoryPath: String) throws -> [EasyLoginMigration] {
    let migrationPaths = try FileManager.default.contentsOfDirectory(atPath: migrationDirectoryPath)
        .filter( {$0.hasPrefix("migration-")} )
        .sorted()
        .map {"\(migrationDirectoryPath)/\($0)"}
    let decoder = JSONDecoder()
    let migrations: [EasyLoginMigration] = try migrationPaths.map {
        path in
        let baseURL = URL(fileURLWithPath: path)
        let manifestURL = baseURL.appendingPathComponent("manifest.json")
        let jsonData = try Data(contentsOf: manifestURL)
        var migration = try decoder.decode(EasyLoginMigration.self, from: jsonData)
        migration.baseURL = baseURL;
        return migration
    }
    return migrations
}

public func bootstrap() throws {
    let configurationManager = ConfigProvider.manager
    let database = try 
        openDatabase(configurationManager: configurationManager)
    var databaseInfo: DatabaseInfo
    if let retrievedDatabaseInfo = try database.retrieveInfo() {
        databaseInfo = retrievedDatabaseInfo
    }
    else {
        databaseInfo = DatabaseInfo()
    }
    let appliedMigrations = Set(databaseInfo.migrations.map {$0.uuid})
    let migrationDirectoryPath = ConfigProvider.pathForResource("migrations")
    let availableMigrations = try getAvailableMigrations(inDirectory: migrationDirectoryPath)
    let newMigrations = availableMigrations.filter {
        !appliedMigrations.contains($0.uuid)
    }
    let now = Date()
    for migration in newMigrations {
        try database.applyMigration(migration)
        databaseInfo.addMigration(uuid: migration.uuid, date: now)
        databaseInfo.revision = try database.saveInfo(databaseInfo)
    }
}
