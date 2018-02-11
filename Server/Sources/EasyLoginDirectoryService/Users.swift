//
//  Users.swift
//  EasyLogin
//
//  Created by Frank on 19/05/17.
//
//

import Foundation
import DataProvider
import Kitura
import LoggerAPI
import Extensions
import NotificationService

class Users {
    let dataProvider: DataProvider
    let numericIDGenerator: PersistentCounter
    let authMethodGenerator: AuthMethodGenerator
    let viewFormatter = ManagedObjectFormatter(type: ManagedUser.self, generator: {ManagedUser.Representation($0)})
    
    init(dataProvider: DataProvider) {
        self.dataProvider = dataProvider
        self.numericIDGenerator = dataProvider.persistentCounter(name: "users.numericID")
        self.authMethodGenerator = AuthMethodGenerator()
    }
    
    func installHandlers(to router: Router) {
        router.get("/users", handler: listUsersHandler)
        router.post("/users", handler: createUserHandler)
        router.get("/users/:uuid", handler: getUserHandler)
        router.put("/users/:uuid", handler: updateUserHandler)
        router.delete("/users/:uuid", handler: deleteUserHandler)
    }
    
    fileprivate func getUserHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        guard let uuid = request.parameters["uuid"] else {
            sendError(.missingField("uuid"), to:response)
            return
        }
        dataProvider.completeManagedObject(ofType: ManagedUser.self, withUUID: uuid) {
            retrievedUser, error in
            if let retrievedUser = retrievedUser, retrievedUser.deleted == false, let jsonData = try? self.viewFormatter.viewAsJSONData(retrievedUser) {
                response.send(data: jsonData)
                response.headers.setType("json")
                response.status(.OK)
            }
            else {
                sendError(.debug("Internal error"), to: response) // TODO: decode error
            }
        }
    }
    
    fileprivate func updateUserHandler(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let uuid = request.parameters["uuid"] else {
            sendError(.missingField("uuid"), to:response)
            next()
            return
        }
        guard let updateRequest = try? request.read(as: MutableManagedUser.UpdateRequest.self) else {
            sendError(.malformedBody, to:response)
            next()
            return
        }
        dataProvider.completeManagedObject(ofType: MutableManagedUser.self, withUUID: uuid) {
            mutableUser, error in
            guard let mutableUser = mutableUser else {
                sendError(.debug("\(String(describing: error))"), to: response)
                // TODO: decode error
                next()
                return
            }
            let initialUser = ManagedUser(with: mutableUser)
            do {
                try mutableUser.update(with: updateRequest, authMethodGenerator: self.authMethodGenerator)
            }
            catch {
                sendError(.debug("\(String(describing: error))"), to: response)
                // TODO: decode error
                next()
                return
            }
            self.dataProvider.storeChangeFrom(mutableManagedObject: mutableUser) {
                updatedUser, error in
                guard let updatedUser = updatedUser else {
                    sendError(.internalServerError, to:response)
                    next()
                    return
                }
                self.updateRelationships(initial: initialUser, final: mutableUser) {
                    error in
                    guard error == nil else {
                        // error --> internal server error, database is inconsistent
                        Log.error("database may be inconsistent!")
                        sendError(.internalServerError, to:response)
                        next()
                        return
                    }
                    if let jsonData = try? self.viewFormatter.viewAsJSONData(updatedUser) {
                        response.send(data: jsonData)
                        response.headers.setType("json")
                        response.status(.OK)
                    }
                    else {
                        sendError(.debug("Internal error"), to: response) // TODO: decode error
                    }
                    next()
                }
            }
        }
    }
    
    fileprivate func createUserHandler(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let updateRequest = try? request.read(as: MutableManagedUser.UpdateRequest.self) else {
            sendError(.malformedBody, to:response)
            next()
            return
        }
        guard let shortname = updateRequest.shortname else {
            sendError(.missingField("shortname"), to:response)
            next()
            return
        }
        guard let principalName = updateRequest.principalName else {
            sendError(.missingField("principalName"), to:response)
            next()
            return
        }
        guard let email = updateRequest.email else {
            sendError(.missingField("email"), to:response)
            next()
            return
        }
        guard let fullName = updateRequest.fullName else {
            sendError(.missingField("fullName"), to:response)
            next()
            return
        }
        let givenName = updateRequest.givenName?.optionalValue
        let surname = updateRequest.surname?.optionalValue
        let authMethods: [String:String]
        if let authMethodsFromRequest = updateRequest.authMethods {
            do {
                authMethods = try authMethodGenerator.generate(authMethodsFromRequest)
            }
            catch {
                sendError(.malformedBody, to: response) // TODO: make error more explicit
                next()
                return
            }
        }
        else {
            authMethods = [:]
        }
        numericIDGenerator.nextValue() { // TODO: generateNextValue()
            numericID in
            guard let numericID = numericID else {
                sendError(.debug("failed to get next numericID"), to:response)
                next()
                return
            }
            let user = MutableManagedUser(withNumericID: numericID, shortname: shortname, principalName: principalName, email: email, givenName: givenName, surname: surname, fullName: fullName, authMethods: authMethods)
            self.dataProvider.insert(mutableManagedObject: user) {
                (insertedUser, error) in
                guard let insertedUser = insertedUser else {
                    sendError(.debug("failed to insert"), to:response)
                    next()
                    return
                }
                NotificationService.notifyAllClients()
                if let jsonData = try? self.viewFormatter.viewAsJSONData(insertedUser) {
                    response.send(data: jsonData)
                    response.headers.setType("json")
                    response.statusCode = .created
                    response.headers.setLocation("/db/users/\(insertedUser.uuid)")
                }
                else {
                    sendError(.debug("Internal error"), to: response) // TODO: decode error
                }
                next()
            }
        }
    }
    
    fileprivate func deleteUserHandler(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let uuid = request.parameters["uuid"] else {
            sendError(.missingField("uuid"), to:response)
            next()
            return
        }
        dataProvider.completeManagedObject(ofType: ManagedUser.self, withUUID: uuid) {
            retrievedUser, error in
            if let retrievedUser = retrievedUser {
                self.dataProvider.delete(managedObject: retrievedUser) {
                    error in
                    guard error == nil else {
                        sendError(.debug("Internal error"), to: response) // TODO: decode error
                        next()
                        return
                    }
                    NotificationService.notifyAllClients()
                    response.status(.noContent)
                    next()
                    return
                }
            }
            else {
                sendError(.notFound, to: response)
                next()
                return
            }
        }
    }
    
    fileprivate func listUsersHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        self.dataProvider.managedObjects(ofType: ManagedUser.self) {
            list, error in
            if let list = list, let jsonData = try? self.viewFormatter.summaryAsJSONData(list) {
                response.send(data: jsonData)
                response.headers.setType("json")
                response.status(.OK)
            }
            else {
                let errorMessage = String(describing: error)
                sendError(.debug("error: \(errorMessage)"), to: response)
            }
        }
    }
    
    fileprivate func updateRelationships(initial: ManagedUser?, final: ManagedUser?, completion: @escaping (Error?) -> Void) {
        let initialOwners = initial?.memberOf ?? []
        let finalOwners = final?.memberOf ?? []
        let (addedOwnerIDs, removedOwnerIDs) = finalOwners.difference(from: initialOwners)
        let groupUUIDsToUpdate = addedOwnerIDs.union(removedOwnerIDs)
        dataProvider.completeManagedObjects(ofType: MutableManagedUserGroup.self, withUUIDs: Array(groupUUIDsToUpdate)) {
            (dict, error) in
            guard error == nil else {
                completion(EasyLoginError.debug(String.init(describing: error)))
                return
            }
            addedOwnerIDs.forEach {
                uuid in
                if let nested = dict[uuid]?.members {
                    dict[uuid]!.setMembers(nested + [final!.uuid])
                }
            }
            removedOwnerIDs.forEach {
                uuid in
                if var nested = dict[uuid]?.members {
                    if let found = nested.index(of: initial!.uuid) {
                        nested.remove(at: found)
                    }
                    dict[uuid]!.setMembers(nested)
                }
            }
            let list = dict.map { $1 }
            self.dataProvider.storeChangesFrom(mutableManagedObjects: list) {
                (updatedList, error) in
                if let error = error {
                    completion(EasyLoginError.debug(String.init(describing: error)))
                }
                else {
                    completion(nil)
                }
            }
        }
    }
}
