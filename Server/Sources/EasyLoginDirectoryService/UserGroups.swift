//
//  UserGroups.swift
//  EasyLoginDirectoryService
//
//  Created by Frank on 03/01/2018.
//

import Foundation
import CouchDB
import DataProvider
import Kitura
import LoggerAPI
import SwiftyJSON
import Extensions
import NotificationService

class UserGroups {
    let database: Database
    let dataProvider: DataProvider
    let numericIDGenerator: PersistentCounter
    
    init(database: Database, dataProvider: DataProvider) {
        self.database = database
        self.dataProvider = dataProvider
        self.numericIDGenerator = PersistentCounter(database: database, name: "usergroups.numericID", initialValue: 1789)
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
            let jsonEncoder = JSONEncoder()
            jsonEncoder.userInfo[.managedObjectCodingStrategy] = ManagedObjectCodingStrategy.apiEncoding(.full)
            if let retrievedUserGroup = retrievedUserGroup, retrievedUserGroup.deleted == false, let jsonData = try? jsonEncoder.encode(retrievedUserGroup) {
                response.send(data: jsonData)
                response.headers.setType("json")
                response.status(.OK)
            }
            else {
                sendError(.debug("Internal error"), to: response) // TODO: decode error
            }
        }
    }
    
    fileprivate func updateUserGroupHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        guard let uuid = request.parameters["uuid"] else {
            sendError(.missingField("uuid"), to:response)
            return
        }
        guard let jsonBody = request.body?.asJSON else {
            Log.error("body parsing failure")
            sendError(.malformedBody, to:response)
            return
        }
        dataProvider.completeManagedObject(ofType: MutableManagedUserGroup.self, withUUID: uuid, completion: {
            retrievedUserGroup, error in
            guard let retrievedUserGroup = retrievedUserGroup else {
                sendError(.debug("\(String(describing: error))"), to: response)
                // TODO: decode error
                return
            }
            do {
                let initialUserGroup = MutableManagedUserGroup(withNumericID: retrievedUserGroup.numericID, shortname: retrievedUserGroup.shortname, commonName: retrievedUserGroup.commonName, email: retrievedUserGroup.email, memberOf: retrievedUserGroup.memberOf, nestedGroups: retrievedUserGroup.nestedGroups, members: retrievedUserGroup.members)
                try retrievedUserGroup.update(withJSON: jsonBody)
                try self.dataProvider.storeChangeFrom(mutableManagedObject: retrievedUserGroup, completion: { (updatedUsergroup, error) in
                    self.updateRelationships(initial: initialUserGroup, final: retrievedUserGroup) {
                        error in
                        guard error == nil else {
                            Log.error("database may be inconsistent!")
                            sendError(.internalServerError, to:response)
                            return
                        }
                        // error --> internal server error, database is inconsistent
                        NotificationService.notifyAllClients()
                        // send view to response
                    }
                })
            }
            catch {
                sendError(.debug("\(String(describing: error))"), to: response)
                // TODO: decode error
                return
            }
        })
    }
    
    fileprivate func createUserGroupHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() } // FIXME: defer to closure, or call explicitly
        Log.debug("handling POST")
        guard let jsonBody = request.body?.asJSON else {
            Log.error("body parsing failure")
            sendError(.malformedBody, to:response)
            return
        }
        guard let shortname = jsonBody["shortname"] as? String else {
            sendError(.missingField("shortname"), to:response)
            return
        }
        guard let commonName = jsonBody["commonName"] as? String else {
            sendError(.missingField("commonName"), to:response)
            return
        }
        let email = jsonBody["email"] as? String
        numericIDGenerator.nextValue() { // TODO: generateNextValue()
            numericID in
            guard let numericID = numericID else {
                sendError(.debug("failed to get next numericID"), to:response)
                return
            }
            let usergroup = MutableManagedUserGroup(withNumericID: numericID, shortname: shortname, commonName: commonName, email: email)
            do {
                try self.dataProvider.insert(mutableManagedObject: usergroup) {
                    (insertedUsergroup, error) in
                    guard let insertedUsergroup = insertedUsergroup else {
                        sendError(.debug("failed to insert"), to:response)
                        return
                    }
                    NotificationService.notifyAllClients()
                    response.statusCode = .created
                    response.headers.setLocation("/db/usergroups/\(insertedUsergroup.uuid)")
                    // send view to response
                }
            }
            catch {
                sendError(.debug("failed to insert: \(error)"), to:response)
            }
        }
    }
    
    fileprivate func deleteUserGroupHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        guard let uuid = request.parameters["uuid"] else {
            sendError(.missingField("uuid"), to:response)
            return
        }
        dataProvider.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: uuid) {
            retrievedUserGroup, error in
            if let retrievedUserGroup = retrievedUserGroup {
                do {
                    try self.dataProvider.delete(managedObject: retrievedUserGroup) {
                        error in
                        guard error == nil else {
                            sendError(.debug("Internal error"), to: response) // TODO: decode error
                            return
                        }
                        NotificationService.notifyAllClients()
                        response.status(.noContent)
                        return
                    }
                }
                catch {
                    sendError(.debug("Internal error"), to: response) // TODO: decode error
                    return
                }
            }
            else {
                sendError(.notFound, to: response)
                return
            }
        }
    }
    
    fileprivate func listUserGroupsHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        self.dataProvider.managedObjects(ofType: ManagedUserGroup.self) {
            list, error in
            let jsonEncoder = JSONEncoder()
            jsonEncoder.userInfo[.managedObjectCodingStrategy] = ManagedObjectCodingStrategy.apiEncoding(.list)
            if let list = list, let jsonData = try? jsonEncoder.encode(list) {
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
    
    fileprivate func updateRelationships(initial: ManagedUserGroup?, final: ManagedUserGroup?, completion: (Error?) -> Void) {
        let initialOwners = initial?.memberOf ?? []
        let finalOwners = final?.memberOf ?? []
        let (addedOwnerIDs, removedOwnerIDs) = diffArrays(initial: initialOwners, final: finalOwners)
        // update
        let initialNestedGroups = initial?.nestedGroups ?? []
        let finalNestedGroups = final?.nestedGroups ?? []
        let (addedNestedGroupIDs, removedNestedGroupIDs) = diffArrays(initial: initialNestedGroups, final: finalNestedGroups)
        // update
        let initialMembers = initial?.members ?? []
        let finalMembers = final?.members ?? []
        let (addedMemberIDs, removedMemberIDs) = diffArrays(initial: initialMembers, final: finalMembers)
        // update
    }
}

extension MutableManagedUserGroup {
    func update(withJSON json: [String: Any]) throws {
        // TODO: implement
        // !!! difference between no key and key: null
    }
}

func diffArrays(initial: [String], final: [String]) -> (added: [String], removed: [String]) {
    let initialSet = Set(initial)
    let finalSet = Set(final)
    let addedSet = finalSet.subtracting(initialSet)
    let removedSet = initialSet.subtracting(finalSet)
    return (Array(addedSet), Array(removedSet))
}

