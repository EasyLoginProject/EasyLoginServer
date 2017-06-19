//
//  DatabaseUsers.swift
//  EasyLogin
//
//  Created by Frank on 19/05/17.
//
//

import Foundation
import CouchDB
import Kitura
import LoggerAPI
import SwiftyJSON
import Extensions

enum UsersError: Error {
    case databaseFailure
}

extension Router {
    func installDatabaseUsersHandlers() {
        self.get("/users", handler: listUsersHandler)
        self.get("/users/:uuid", handler: getUserHandler)
        self.post("/users", handler: createUserHandler)
    }
}

fileprivate func getUserHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
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

fileprivate func createUserHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
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
        insert(user, into: database) {
            createdUser in
            guard let createdUser = createdUser else {
                sendError(to: response)
                return
            }
            response.statusCode = .created
            response.headers.setLocation("/db/users/\(createdUser.uuid)")
            response.send(json: createdUser.responseElement())
        }
    default:
        sendError(to: response)
    }
}

fileprivate func listUsersHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
    defer { next() }
    guard let database = database else {
        sendError(to: response)
        return
    }
    database.queryByView("all_users", ofDesign: "main_design", usingParameters: []) { (databaseResponse, error) in
        guard let databaseResponse = databaseResponse else {
            sendError(to: response)
            return
        }
        let userList = databaseResponse["rows"].array?.flatMap { user -> [String:Any]? in
            if let uuid = user["value"]["uuid"].string,
               let numericID = user["value"]["numericID"].int,
               let shortname = user["value"]["shortname"].string {
                return ["uuid":uuid, "numericID":numericID, "shortname":shortname]
            }
            return nil
        }
        let result = ["users": userList ?? []]
        response.send(json: JSON(result))
    }
}

fileprivate func insert(_ user: ManagedUser, into database: Database, completion: @escaping (ManagedUser?) -> Void) -> Void {
    nextNumericID(database: database) {
        numericID in
        Log.debug("next numeric id = \(numericID)")
        var userWithID = user
        userWithID.numericID = numericID
        let document = JSON(userWithID.databaseRecord())
        database.create(document, callback: { (id: String?, rev: String?, createdDocument: JSON?, error: NSError?) in
            guard createdDocument != nil else {
                completion(nil)
                return
            }
            let createdUser = ManagedUser(databaseRecord:document)
            completion(createdUser)
        })
    }
}

fileprivate func nextNumericID(database: Database, _ block: @escaping (Int)->Void) -> Void {
    database.queryByView("users_numeric_id", ofDesign: "main_design", usingParameters: []) { (databaseResponse, error) in
        if let lastNumericID = databaseResponse?["rows"][0]["value"]["max"].int {
            block(lastNumericID + 1)
        }
        else {
            block(1)
        }
    }
}

