//
//  UserGroups.swift
//  EasyLoginDirectoryService
//
//  Created by Frank on 03/01/2018.
//

import Foundation
import DataProvider
import Kitura
import LoggerAPI
import Extensions
import NotificationService

class UserGroups {
    let dataProvider: DataProvider
    let numericIDGenerator: PersistentCounter
    let viewFormatter = ManagedObjectFormatter(type: ManagedUserGroup.self, generator: {ManagedUserGroup.Representation($0)})
    
    init(dataProvider: DataProvider) {
        self.dataProvider = dataProvider
        self.numericIDGenerator = dataProvider.persistentCounter(name: "userGroups.numericID")
    }
    
    func installHandlers(to router: Router) {
        router.get("/usergroups", handler: listUserGroupsHandler)
        router.post("/usergroups", handler: createUserGroupHandler)
        router.get("/usergroups/:uuid", handler: getUserGroupHandler)
        router.put("/usergroups/:uuid", handler: updateUserGroupHandler)
        router.delete("/usergroups/:uuid", handler: deleteUserGroupHandler)
    }
    
    fileprivate func getUserGroupHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        guard let uuid = request.parameters["uuid"] else {
            sendError(.missingField("uuid"), to:response)
            return
        }
        dataProvider.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: uuid) {
            retrievedUserGroup, error in
            if let retrievedUserGroup = retrievedUserGroup, retrievedUserGroup.deleted == false, let jsonData = try? self.viewFormatter.viewAsJSONData(retrievedUserGroup) {
                response.send(data: jsonData)
                response.headers.setType("json")
                response.status(.OK)
            }
            else {
                sendError(.debug("Internal error"), to: response) // TODO: decode error
            }
        }
    }
    
    fileprivate func updateUserGroupHandler(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let uuid = request.parameters["uuid"] else {
            sendError(.missingField("uuid"), to:response)
            next()
            return
        }
        guard let updateRequest = try? request.read(as: MutableManagedUserGroup.UpdateRequest.self) else {
            sendError(.malformedBody, to:response)
            next()
            return
        }
        dataProvider.completeManagedObject(ofType: MutableManagedUserGroup.self, withUUID: uuid) {
            mutableUserGroup, error in
            guard let mutableUserGroup = mutableUserGroup else {
                sendError(.debug("\(String(describing: error))"), to: response)
                // TODO: decode error
                next()
                return
            }
            mutableUserGroup.update(with: updateRequest) {
                error in
                guard error == nil else {
                    sendError(.debug("\(String(describing: error))"), to: response)
                    // TODO: decode error
                    next()
                    return
                }
                self.dataProvider.storeChangeFrom(mutableManagedObject: mutableUserGroup) {
                    updatedUsergroup, error in
                    guard let updatedUsergroup = updatedUsergroup else {
                        sendError(.internalServerError, to:response)
                        next()
                        return
                    }
                    if let jsonData = try? self.viewFormatter.viewAsJSONData(updatedUsergroup) {
                        response.send(data: jsonData)
                        response.headers.setType("json")
                        response.status(.OK)
                    }
                    else {
                        sendError(.debug("Internal error"), to: response) // TODO: decode error
                    }
                    next()
                    return
                }
            }
        }
    }
    
    fileprivate func createUserGroupHandler(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let updateRequest = try? request.read(as: MutableManagedUserGroup.UpdateRequest.self) else {
            sendError(.malformedBody, to:response)
            next()
            return
        }
        guard let shortname = updateRequest.shortname else {
            sendError(.missingField("shortname"), to:response)
            next()
            return
        }
        guard let commonName = updateRequest.commonName else {
            sendError(.missingField("commonName"), to:response)
            next()
            return
        }
        let email = updateRequest.email?.optionalValue
        let memberOf = updateRequest.memberOf ?? []
        let nestedGroups = updateRequest.nestedGroups ?? []
        let members = updateRequest.members ?? []
        numericIDGenerator.nextValue() { // TODO: generateNextValue()
            numericID in
            guard let numericID = numericID else {
                sendError(.debug("failed to get next numericID"), to:response)
                next()
                return
            }
            let usergroup = MutableManagedUserGroup(withDataProvider: self.dataProvider, numericID: numericID, shortname: shortname, commonName: commonName, email: email)
            usergroup.setRelationships(memberOf: memberOf, nestedGroups: nestedGroups, members: members) {
                error in
                guard error == nil else {
                    sendError(.debug("failed to update relationships: \(String(describing: error))"), to:response)
                    next()
                    return
                }
                self.dataProvider.insert(mutableManagedObject: usergroup) {
                    (insertedUsergroup, error) in
                    guard let insertedUsergroup = insertedUsergroup else {
                        sendError(.debug("failed to insert"), to:response)
                        next()
                        return
                    }
                    NotificationService.notifyAllClients()
                    if let jsonData = try? self.viewFormatter.viewAsJSONData(insertedUsergroup) {
                        response.send(data: jsonData)
                        response.headers.setType("json")
                        response.statusCode = .created
                        response.headers.setLocation("/db/usergroups/\(insertedUsergroup.uuid)")
                    }
                    else {
                        sendError(.debug("Internal error"), to: response) // TODO: decode error
                    }
                    next()
                }
            }
        }
    }
    
    fileprivate func deleteUserGroupHandler(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let uuid = request.parameters["uuid"] else {
            sendError(.missingField("uuid"), to:response)
            next()
            return
        }
        dataProvider.completeManagedObject(ofType: MutableManagedUserGroup.self, withUUID: uuid) {
            retrievedUserGroup, error in
            if let retrievedUserGroup = retrievedUserGroup {
                retrievedUserGroup.setRelationships(memberOf: [], nestedGroups: [], members: []) {
                    error in
                    guard error == nil else {
                        sendError(.debug("Internal error (delete relationships)"), to: response) // TODO: decode error
                        next()
                        return
                    }
                    self.dataProvider.delete(managedObject: retrievedUserGroup) {
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
            }
            else {
                sendError(.notFound, to: response)
                next()
                return
            }
        }
    }
    
    fileprivate func listUserGroupsHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        self.dataProvider.managedObjects(ofType: ManagedUserGroup.self) {
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
}

