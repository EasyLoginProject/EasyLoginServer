//
//  DatabaseUsers.swift
//  EasyLogin
//
//  Created by Frank on 19/05/17.
//
//

import Foundation
import Kitura
import LoggerAPI
import SwiftyJSON

extension Router {
    public func installDatabaseUsersHandlers() {
        self.get("/db/users/:uuid", handler: getUserHandler)
        self.post("/db/users", handler: createUserHandler)
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
