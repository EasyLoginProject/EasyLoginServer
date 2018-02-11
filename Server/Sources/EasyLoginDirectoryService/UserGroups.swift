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
        guard let updateRequest = try? request.read(as: MutableManagedUserGroup.UpdateRequest.self) else {
            sendError(.malformedBody, to:response)
            next()
            return
        }
        dataProvider.completeManagedObject(ofType: MutableManagedUserGroup.self, withUUID: uuid) {
            retrievedUserGroup, error in
            guard let retrievedUserGroup = retrievedUserGroup else {
                sendError(.debug("\(String(describing: error))"), to: response)
                // TODO: decode error
                next()
                return
            }
            let initialUserGroup = MutableManagedUserGroup(withNumericID: retrievedUserGroup.numericID, shortname: retrievedUserGroup.shortname, commonName: retrievedUserGroup.commonName, email: retrievedUserGroup.email, memberOf: retrievedUserGroup.memberOf, nestedGroups: retrievedUserGroup.nestedGroups, members: retrievedUserGroup.members)
            do {
                try retrievedUserGroup.update(with: updateRequest)
            }
            catch {
                sendError(.debug("\(String(describing: error))"), to: response)
                // TODO: decode error
                next()
                return
            }
            self.dataProvider.storeChangeFrom(mutableManagedObject: retrievedUserGroup) {
                updatedUsergroup, error in
                guard let updatedUsergroup = updatedUsergroup else {
                    sendError(.internalServerError, to:response)
                    next()
                    return
                }
                self.updateRelationships(initial: initialUserGroup, final: retrievedUserGroup) {
                    error in
                    guard error == nil else {
                        // error --> internal server error, database is inconsistent
                        Log.error("database may be inconsistent!")
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
        let (addedOwnerIDs, removedOwnerIDs) = finalOwners.difference(from: initialOwners)
        let initialNestedGroups = initial?.nestedGroups ?? []
        let finalNestedGroups = final?.nestedGroups ?? []
        let (addedNestedGroupIDs, removedNestedGroupIDs) = finalNestedGroups.difference(from: initialNestedGroups)
        let initialMembers = initial?.members ?? []
        let finalMembers = final?.members ?? []
        let (addedMemberIDs, removedMemberIDs) = finalMembers.difference(from: initialMembers)
        let groupUUIDsToUpdate = addedOwnerIDs.union(removedOwnerIDs).union(addedNestedGroupIDs).union(removedNestedGroupIDs)
        let userUUIDsToUpdate = addedMemberIDs.union(removedMemberIDs)
        dataProvider.completeManagedObjects(ofType: MutableManagedUserGroup.self, withUUIDs: Array(groupUUIDsToUpdate)) {
            (dict, error) in
            guard error == nil else {
                completion(EasyLoginError.debug(String.init(describing: error)))
                return
            }
            self.dataProvider.completeManagedObjects(ofType: MutableManagedUser.self, withUUIDs: Array(userUUIDsToUpdate)) {
                userDict, error in
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
                addedMemberIDs.forEach {
                    uuid in
                    if let owners = userDict[uuid]?.memberOf {
                        userDict[uuid]!.setOwners(owners + [final!.uuid])
                    }
                }
                removedMemberIDs.forEach {
                    uuid in
                    if var owners = userDict[uuid]?.memberOf {
                        if let found = owners.index(of: initial!.uuid) {
                            owners.remove(at: found)
                        }
                        dict[uuid]!.setOwners(owners)
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
}

