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

func sendError(to response: RouterResponse) {
    response.send("This is unexpected.")
}

public let manager = ConfigurationManager()
public let router = Router()

internal var database: Database?

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
        database = couchDBClient.database(databaseName)
    }
    else if let cloudantService = try? manager.getCloudantService(name: "EasyLogin-Cloudant") {
        let databaseName = "easy_login"
        let couchDBClient = CouchDBClient(service: cloudantService)
        Log.info("Connected to Cloudant, client = \(couchDBClient), database name = \(databaseName)")
        database = couchDBClient.database(databaseName)
    }
    else {
        throw ConfigError.missingDatabaseInfo
    }
    
    router.post(middleware:BodyParser())
    router.put(middleware:BodyParser())
    
    router.get("/db/users/:uuid") {
        request, response, next in
        defer { next() }
        guard let uuid = request.parameters["uuid"] else {
            sendError(to:response)
            return
        }
        guard let database = database else {
            sendError(to: response)
            return
        }
        database.retrieve(uuid, callback: { (document: JSON?, error: NSError?) in
            guard let document = document else {
                sendError(to: response)
                return
            }
            guard let retrievedUser = ManagedUser(databaseRecord:document) else {
                sendError(to: response)
                return
            }
            response.send(json: retrievedUser.responseElement())
        })
    }
    
    router.post("/db/users") {
        request, response, next in
        defer { next() }
        Log.debug("handling POST")
        guard let parsedBody = request.body else {
            Log.error("body parsing failure")
            sendError(to:response)
            return
        }
        Log.debug("handling body")
        switch(parsedBody) {
        case .json(let jsonBody):
            guard let user = ManagedUser(requestElement:jsonBody) else {
                sendError(to: response)
                return
            }
            guard let database = database else {
                sendError(to: response)
                return
            }
            let document = JSON(user.databaseRecord())
            database.create(document, callback: { (id: String?, rev: String?, createdDocument: JSON?, error: NSError?) in
                guard let createdDocument = createdDocument else {
                    sendError(to: response)
                    return
                }
                guard let createdUser = ManagedUser(databaseRecord:document) else {
                    sendError(to: response)
                    return
                }
                response.send(json: createdUser.responseElement())
            })
        default:
            sendError(to: response)
        }
    }
}

public func run() throws {
    Kitura.addHTTPServer(onPort: 8080, with: router)
    Kitura.run()
}
