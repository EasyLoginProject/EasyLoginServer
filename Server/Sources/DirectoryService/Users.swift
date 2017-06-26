//
//  Users.swift
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
import NotificationService

enum UsersError: Error {
    case databaseFailure
}

class Users {
    let database: Database
    
    init(database: Database) {
        self.database = database
    }
    
    func installHandlers(to router: Router) {
        router.get("/users", handler: listUsersHandler)
        router.post("/users", handler: createUserHandler)
        router.get("/users/:uuid", handler: getUserHandler)
        router.put("/users/:uuid", handler: updateUserHandler)
    }
    
    func getUserHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        guard let uuid = request.parameters["uuid"] else {
            sendError(.missingField("uuid"), to:response)
            return
        }
        database.retrieve(uuid, callback: { (document: JSON?, error: NSError?) in
            guard let document = document else {
                sendError(.notFound, to: response)
                return
            }
            // TODO: verify type == "user"
            // TODO: verify not deleted
            do {
                let retrievedUser = try ManagedUser(databaseRecord:document)
                response.send(json: try retrievedUser.responseElement())
            }
            catch let error as EasyLoginError {
                sendError(error, to: response)
            }
            catch {
                sendError(.debug("Internal error"), to: response)
            }
        })
    }
    
    func updateUserHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        guard let uuid = request.parameters["uuid"] else {
            sendError(.missingField("uuid"), to:response)
            return
        }
        database.retrieve(uuid, callback: { (document: JSON?, error: NSError?) in
            guard let document = document else {
                sendError(.notFound, to: response)
                return
            }
            // TODO: verify type == "user"
            // TODO: verify not deleted
            guard let parsedBody = request.body else {
                Log.error("body parsing failure")
                sendError(.malformedBody, to:response)
                return
            }
            switch(parsedBody) {
            case .json(let jsonBody):
                do {
                    let retrievedUser = try ManagedUser(databaseRecord:document)
                    let updatedUser = try retrievedUser.updated(with: jsonBody)
                    update(updatedUser, into: self.database) { (writtenUser, error) in
                        guard writtenUser != nil else {
                            let errorMessage = error?.localizedDescription ?? "error is nil"
                            sendError(.debug("Response creation failed: \(errorMessage)"), to: response)
                            return
                        }
                        NotificationService.notifyAllClients()
                        response.statusCode = .OK
                        response.headers.setLocation("/db/users/\(updatedUser.uuid)")
                        response.send(json: try! updatedUser.responseElement())
                    }
                }
                catch let error as EasyLoginError {
                    sendError(error, to: response)
                }
                catch {
                    sendError(.debug("Internal error"), to: response)
                }
            default:
                sendError(.malformedBody, to: response)
            }
        })
    }
    
    func createUserHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() } // FIXME: defer to closure, or call explicitly
        Log.debug("handling POST")
        guard let parsedBody = request.body else {
            Log.error("body parsing failure")
            sendError(.malformedBody, to:response)
            return
        }
        Log.debug("handling body")
        switch(parsedBody) {
        case .json(let jsonBody):
            do {
                let user = try ManagedUser(requestElement:jsonBody)
                insert(user, into: database) {
                    createdUser, error in
                    guard let createdUser = createdUser else {
                        let errorMessage = error?.localizedDescription ?? "error is nil"
                        sendError(.debug("Response creation failed: \(errorMessage)"), to: response)
                        return
                    }
                    NotificationService.notifyAllClients()
                    response.statusCode = .created
                    response.headers.setLocation("/db/users/\(createdUser.uuid)")
                    response.send(json: try! createdUser.responseElement())
                }
            }
            catch let error as EasyLoginError {
                sendError(error, to: response)
            }
            catch {
                sendError(.debug("User creation failed"), to: response)
            }
        default:
            sendError(.malformedBody, to: response)
        }
    }
    
    func listUsersHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        database.queryByView("all_users", ofDesign: "main_design", usingParameters: []) { (databaseResponse, error) in
            guard let databaseResponse = databaseResponse else {
                let errorMessage = error?.localizedDescription ?? "error is nil"
                sendError(.debug("Database request failed: \(errorMessage)"), to: response)
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
}

fileprivate func insert(_ user: ManagedUser, into database: Database, completion: @escaping (ManagedUser?, NSError?) -> Void) -> Void {
    // TODO: ensure shortName and principalName are unique
    nextNumericID(database: database) {
        numericID in
        Log.debug("next numeric id = \(numericID)")
        guard let userWithID = try? user.inserted(newNumericID: numericID) else {
            completion(nil, NSError(domain: "EasyLogin", code: 1, userInfo: nil)) // FIXME: define error
            return
        }
        let document = try! JSON(userWithID.databaseRecord())
        database.create(document, callback: { (id: String?, rev: String?, createdDocument: JSON?, error: NSError?) in
            guard createdDocument != nil else {
                completion(nil, error)
                return
            }
            do {
                let createdUser = try ManagedUser(databaseRecord:document)
                completion(createdUser, nil)
            }
            catch {
                completion(nil, nil) // TODO: set error
            }
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

fileprivate func update(_ user: ManagedUser, into database: Database, completion: @escaping (ManagedUser?, NSError?) -> Void) -> Void {
    let document = try! JSON(user.databaseRecord())
    database.update(user.uuid!, rev: user.revision!, document: document, callback: { (rev: String?, updatedDocument: JSON?, error: NSError?) in
        guard updatedDocument != nil else {
            completion(nil, error)
            return
        }
        do {
            let updatedUser = try ManagedUser(databaseRecord:document)
            completion(updatedUser, nil)
        }
        catch {
            completion(nil, nil) // TODO: set error
        }
    })
}
