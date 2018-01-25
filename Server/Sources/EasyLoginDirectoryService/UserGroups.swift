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
        self.numericIDGenerator = dataProvider.persistentCounter(name: "usergroups.numericID")
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
        guard let jsonBody = request.body?.asJSON else {
            Log.error("body parsing failure")
            sendError(.malformedBody, to:response)
            next()
            return
        }
        dataProvider.completeManagedObject(ofType: MutableManagedUserGroup.self, withUUID: uuid, completion: {
            retrievedUserGroup, error in
            guard let retrievedUserGroup = retrievedUserGroup else {
                sendError(.debug("\(String(describing: error))"), to: response)
                // TODO: decode error
                next()
                return
            }
                let initialUserGroup = MutableManagedUserGroup(withNumericID: retrievedUserGroup.numericID, shortname: retrievedUserGroup.shortname, commonName: retrievedUserGroup.commonName, email: retrievedUserGroup.email, memberOf: retrievedUserGroup.memberOf, nestedGroups: retrievedUserGroup.nestedGroups, members: retrievedUserGroup.members)
            do {
                try retrievedUserGroup.update(withJSON: jsonBody)
            }
            catch {
                sendError(.debug("\(String(describing: error))"), to: response)
                // TODO: decode error
                next()
                return
            }
            self.dataProvider.storeChangeFrom(mutableManagedObject: retrievedUserGroup, completion: { (updatedUsergroup, error) in
                self.updateRelationships(initial: initialUserGroup, final: retrievedUserGroup) {
                    error in
                    guard error == nil else {
                        // error --> internal server error, database is inconsistent
                        Log.error("database may be inconsistent!")
                        sendError(.internalServerError, to:response)
                        next()
                        return
                    }
                    if let jsonData = try? self.viewFormatter.viewAsJSONData(retrievedUserGroup) {
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
            })
        })
    }
    
    fileprivate func createUserGroupHandler(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        Log.debug("handling POST")
        guard let jsonBody = request.body?.asJSON else {
            Log.error("body parsing failure")
            sendError(.malformedBody, to:response)
            next()
            return
        }
        guard let shortname = jsonBody["shortname"] as? String else {
            sendError(.missingField("shortname"), to:response)
            next()
            return
        }
        guard let commonName = jsonBody["commonName"] as? String else {
            sendError(.missingField("commonName"), to:response)
            next()
            return
        }
        let email = jsonBody["email"] as? String
        let memberOf = jsonBody["memberOf"] as? [String] ?? []
        let nestedGroups = jsonBody["nestedGroups"] as? [String] ?? []
        let members = jsonBody["members"] as? [String] ?? []
        numericIDGenerator.nextValue() { // TODO: generateNextValue()
            numericID in
            guard let numericID = numericID else {
                sendError(.debug("failed to get next numericID"), to:response)
                next()
                return
            }
            let usergroup = MutableManagedUserGroup(withNumericID: numericID, shortname: shortname, commonName: commonName, email: email, memberOf: memberOf, nestedGroups: nestedGroups, members: members)
            self.updateRelationships(initial: nil, final: usergroup) {
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
        dataProvider.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: uuid) {
            retrievedUserGroup, error in
            if let retrievedUserGroup = retrievedUserGroup {
                self.updateRelationships(initial: retrievedUserGroup, final: nil) {
                    error in
                    guard error == nil else {
                        sendError(.debug("Internal error"), to: response) // TODO: decode error
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
    
    fileprivate func updateRelationships(initial: ManagedUserGroup?, final: ManagedUserGroup?, completion: @escaping (Error?) -> Void) {
        let initialOwners = initial?.memberOf ?? []
        let finalOwners = final?.memberOf ?? []
        let (addedOwnerIDs, removedOwnerIDs) = diffArrays(initial: initialOwners, final: finalOwners)
        let initialNestedGroups = initial?.nestedGroups ?? []
        let finalNestedGroups = final?.nestedGroups ?? []
        let (addedNestedGroupIDs, removedNestedGroupIDs) = diffArrays(initial: initialNestedGroups, final: finalNestedGroups)
        let initialMembers = initial?.members ?? []
        let finalMembers = final?.members ?? []
        let (addedMemberIDs, removedMemberIDs) = diffArrays(initial: initialMembers, final: finalMembers)
        let groupUUIDsToUpdate = Array(Set(addedOwnerIDs + removedOwnerIDs + addedNestedGroupIDs + removedNestedGroupIDs))
        let userUUIDsToUpdate = Array(Set(addedMemberIDs + removedMemberIDs))
        dataProvider.completeManagedObjects(ofType: MutableManagedUserGroup.self, withUUIDs: groupUUIDsToUpdate) {
            (dict, error) in
            guard error == nil else {
                completion(EasyLoginError.debug(String.init(describing: error)))
                return
            }
            addedOwnerIDs.forEach {
                uuid in
                if let nested = dict[uuid]?.nestedGroups {
                    dict[uuid]!.setNestedGroups(nested + [final!.uuid])
                }
            }
            removedOwnerIDs.forEach {
                uuid in
                if var nested = dict[uuid]?.nestedGroups {
                    if let found = nested.index(of: initial!.uuid) {
                        nested.remove(at: found)
                    }
                    dict[uuid]!.setNestedGroups(nested)
                }
            }
            addedNestedGroupIDs.forEach {
                uuid in
                if let owners = dict[uuid]?.memberOf {
                    dict[uuid]!.setOwners(owners + [final!.uuid])
                }
            }
            removedNestedGroupIDs.forEach {
                uuid in
                if var owners = dict[uuid]?.memberOf {
                    if let found = owners.index(of: initial!.uuid) {
                        owners.remove(at: found)
                    }
                    dict[uuid]!.setOwners(owners)
                }
            }
            // TODO: same with members when Users are moved to DataProvider
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

extension MutableManagedUserGroup {
    func update(withJSON jsonBody: [String: Any]) throws {
        if let commonName = jsonBody["commonName"] as? String {
            self.setCommonName(commonName)
        }
        if let email = jsonBody["email"] as? String {
            try self.setEmail(email)
        }
        else if jsonBody["email"] is NSNull {
            self.clearEmail()
        }
        if let memberOf = jsonBody["memberOf"] as? [String] {
            self.setOwners(memberOf)
        }
        if let nestedGroups = jsonBody["nestedGroups"] as? [String] {
            self.setNestedGroups(nestedGroups)
        }
        if let members = jsonBody["members"] as? [String] {
            self.setMembers(members)
        }
    }
}

func diffArrays(initial: [String], final: [String]) -> (added: [String], removed: [String]) {
    let initialSet = Set(initial)
    let finalSet = Set(final)
    let addedSet = finalSet.subtracting(initialSet)
    let removedSet = initialSet.subtracting(finalSet)
    return (Array(addedSet), Array(removedSet))
}

