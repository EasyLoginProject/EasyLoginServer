//
//  AdminAPIUserGroups.swift
//  EasyLoginAdminAPI
//
//  Created by Yoann Gini on 01/02/2018.
//

import Foundation
import DataProvider
import Kitura
import Dispatch

struct DesiredUserGroupFromAdminAPI: Codable {
    let shortname: String?
    let email: String?
    let commonName: String?
    let members: [String]?
    let memberOf: [String]?
    let nestedGroups: [String]?
    
    func update(mutableManagedUserGroup:MutableManagedUserGroup) throws {
        if let shortname = shortname {
            try mutableManagedUserGroup.setShortname(shortname)
        }
        if let commonName = commonName {
            mutableManagedUserGroup.setCommonName(commonName)
        }
        if let email = email {
            try mutableManagedUserGroup.setEmail(email)
        }
        
        let validMembersIDs = members?.flatMap({ (memberUUID) -> ManagedObjectRecordID? in
            var finalRecordID: ManagedObjectRecordID? = nil
            let semaphore = DispatchSemaphore(value: 0)
            mutableManagedUserGroup.dataProvider!.managedObjectRecordID(forObjectOfType: ManagedUser.self, withSupposedUUID: memberUUID, completion: { (recordID, error) in
                finalRecordID = recordID
                semaphore.signal()
            })
            semaphore.wait()
            return finalRecordID
        })
        
        let validParentGroupIDs = memberOf?.flatMap({ (memberUUID) -> ManagedObjectRecordID? in
            var finalRecordID: ManagedObjectRecordID? = nil
            let semaphore = DispatchSemaphore(value: 0)
            mutableManagedUserGroup.dataProvider!.managedObjectRecordID(forObjectOfType: ManagedUserGroup.self, withSupposedUUID: memberUUID, completion: { (recordID, error) in
                finalRecordID = recordID
                semaphore.signal()
            })
            semaphore.wait()
            return finalRecordID
        })
        
        let validNestedGroupsIDs = nestedGroups?.flatMap({ (memberUUID) -> ManagedObjectRecordID? in
            var finalRecordID: ManagedObjectRecordID? = nil
            let semaphore = DispatchSemaphore(value: 0)
            mutableManagedUserGroup.dataProvider!.managedObjectRecordID(forObjectOfType: ManagedUserGroup.self, withSupposedUUID: memberUUID, completion: { (recordID, error) in
                finalRecordID = recordID
                semaphore.signal()
            })
            semaphore.wait()
            return finalRecordID
        })
        
        let finalMembersIDs = validMembersIDs ?? mutableManagedUserGroup.members
        let finalParentGroupIDs = validParentGroupIDs ?? mutableManagedUserGroup.memberOf
        let finalNestedGroupsIDs = validNestedGroupsIDs ?? mutableManagedUserGroup.nestedGroups
        
        let semaphore = DispatchSemaphore(value: 0)
        mutableManagedUserGroup.setRelationships(memberOf: finalParentGroupIDs , nestedGroups:finalNestedGroupsIDs , members: finalMembersIDs) { (error) in
            semaphore.signal()
        }
        semaphore.wait()
    }
    
    func createNewMutableManagedUserGroup(withDataProvider dataProvider:DataProvider, completion: @escaping (MutableManagedUserGroup?) -> Void) {
        if let shortname = shortname, let commonName = commonName {
            let numericIDGenerator = dataProvider.persistentCounter(name: "userGroups.numericID")
            numericIDGenerator.nextValue(completion: { (numericID) in
                if let numericID = numericID {
                    let newUserGroup = MutableManagedUserGroup(withDataProvider: dataProvider, numericID: numericID, shortname: shortname, commonName: commonName, email: self.email)
                    completion(newUserGroup)
                } else {
                    completion(nil)
                }
            })
            
        } else {
            completion(nil)
        }
    }
}

struct UserGroupForAdminAPI: Codable {
    let uuid: String
    
    let numericID: Int
    let shortname: String
    let commonName: String
    let email: String?
    
    let members: [String]
    let memberOf: [String]
    let nestedGroups: [String]
    
    enum CodingKeys: String, CodingKey {
        case uuid = "id"
        case numericID
        case shortname
        case commonName
        case email
        case members
        case memberOf
        case nestedGroups
    }
    
    init(managedUserGroup: ManagedUserGroup) {
        uuid = managedUserGroup.uuid
        numericID = managedUserGroup.numericID
        shortname = managedUserGroup.shortname
        commonName = managedUserGroup.commonName
        email = managedUserGroup.email
        members = managedUserGroup.members
        memberOf = managedUserGroup.memberOf
        nestedGroups = managedUserGroup.nestedGroups
    }
}

public class AdminAPIUserGroups {
    let dataProvider: DataProvider
    
    public init(dataProvider: DataProvider) {
        self.dataProvider = dataProvider
    }
    
    public func setupRouter(_ router:Router) {
        router.get("/usergroups", handler: getUserGroups)
        router.post("/usergroups", handler: createUserGroup)
        router.get("/usergroups/:uuid", handler: getUserGroup)
        router.put("/usergroups/:uuid", handler: updateUserGroup)
        router.delete("/usergroups/:uuid", handler: deleteUserGroup)
    }
    
    func getUserGroups(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        dataProvider.completeManagedObjects(ofType: ManagedUserGroup.self) { (managedUserGroups, error) in
            guard var managedUserGroups = managedUserGroups else {
                response.status(.internalServerError)
                next()
                return
            }
            
            for (param, value) in request.queryParameters where !param.hasPrefix("_") {
                if let key = UserGroupForAdminAPI.CodingKeys(stringValue: param) {
                    managedUserGroups = managedUserGroups.filter({ (managedUserGroup) -> Bool in
                        switch key {
                        case .uuid:
                            return managedUserGroup.uuid.contains(value)
                        case .shortname:
                            return managedUserGroup.shortname.contains(value)
                        case .commonName:
                            return managedUserGroup.commonName.contains(value)
                        case .email:
                            if let email = managedUserGroup.email {
                                return email.contains(value)
                            } else {
                                return false
                            }
                        case .numericID:
                            return String(managedUserGroup.numericID).contains(value)
                        case .members, .memberOf, .nestedGroups:
                            //TODO Implement real member nested fetch
                            return false
                        }
                    })
                }
            }
            
            
            if let globalQuery = request.queryParameters["q"] {
                let globalQuery = globalQuery.lowercased()
                managedUserGroups = managedUserGroups.filter({ (managedUserGroup) -> Bool in
                    if managedUserGroup.shortname.lowercased().contains(globalQuery) {
                        return true
                    } else if managedUserGroup.commonName.lowercased().contains(globalQuery) {
                        return true
                    } else {
                        return false
                    }
                })
            }
            
            let sortKey: UserGroupForAdminAPI.CodingKeys
            if let sortField = request.queryParameters["_sort"] {
                if let requestedSortKey = UserGroupForAdminAPI.CodingKeys(stringValue: sortField) {
                    sortKey = requestedSortKey
                } else {
                    sortKey = .shortname
                }
            } else {
                sortKey = .shortname
            }
            
            let ascending: Bool
            if let orderField = request.queryParameters["_order"] {
                ascending = orderField == "ASC"
            } else {
                ascending = true
            }
            
            managedUserGroups.sort(by: { (left, right) -> Bool in
                let isAscendent: Bool
                switch sortKey {
                case .uuid:
                    isAscendent = left.uuid < right.uuid
                case .shortname:
                    isAscendent = left.shortname < right.shortname
                case .commonName:
                    isAscendent = left.commonName < right.commonName
                case .email:
                    if let lv = left.email, let rv = right.email {
                        isAscendent = lv < rv
                    } else if let _ = right.email {
                        isAscendent = true
                    } else if let _ = left.email {
                        isAscendent = false
                    } else {
                        isAscendent = left.numericID < right.numericID
                    }
                case .numericID:
                    isAscendent = left.numericID < right.numericID
                default:
                    isAscendent = left.uuid < right.uuid
                }
                
                if ascending {
                    return isAscendent
                } else {
                    return !isAscendent
                }
            })
            
            guard managedUserGroups.count != 0 else {
                if let jsonData = try? JSONEncoder().encode([String]()) {
                    response.headers.append("X-Total-Count", value: String(managedUserGroups.count))
                    response.headers.setType("json")
                    response.send(data: jsonData)
                    response.status(.OK)
                    next()
                    return
                } else {
                    response.status(.internalServerError)
                    next()
                    return
                }
            }
            
            let first: Int
            if let startValue = request.queryParameters["_start"], let start = Int(startValue), start >= 0 {
                first = start
            } else {
                first = 0
            }
            
            let last: Int
            if let endValue = request.queryParameters["_end"], let end = Int(endValue), end-1 < managedUserGroups.count {
                last = end-1
            } else {
                last = managedUserGroups.count - 1
            }
            
            var selectedUserGroups = [UserGroupForAdminAPI]()
            
            for index in first...last {
                selectedUserGroups.append(UserGroupForAdminAPI(managedUserGroup: managedUserGroups[index]))
            }
            
            if let jsonData = try? JSONEncoder().encode(selectedUserGroups) {
                response.headers.append("X-Total-Count", value: String(managedUserGroups.count))
                response.headers.setType("json")
                response.send(data: jsonData)
                response.status(.OK)
                next()
                return
            } else {
                response.status(.internalServerError)
                next()
                return
            }
        }
    }
    
    func getUserGroup(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let recordUUID = request.parameters["uuid"] else {
            response.status(.badRequest)
            next()
            return
        }
        
        dataProvider.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordUUID) { (managedUserGroup, error) in
            guard let managedUserGroup = managedUserGroup else {
                response.status(.notFound)
                next()
                return
            }
            
            let userForAdminAPI = UserGroupForAdminAPI(managedUserGroup: managedUserGroup)
            
            if let jsonData = try? JSONEncoder().encode(userForAdminAPI) {
                response.headers.setType("json")
                response.send(data: jsonData)
                response.status(.OK)
                next()
                return
            } else {
                response.status(.internalServerError)
                next()
                return
            }
        }
    }
    
    func updateUserGroup(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let contentType = request.headers["Content-Type"] else {
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard contentType.hasPrefix("application/json") else {
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard let recordUUID = request.parameters["uuid"] else {
            response.status(.badRequest)
            next()
            return
        }
        
        if let desiredUserGroupFromAdminAPI = try? request.read(as: DesiredUserGroupFromAdminAPI.self) {
            dataProvider.completeManagedObject(ofType: MutableManagedUserGroup.self, withUUID: recordUUID) { (mutableManagedUserGroup, error) in
                guard let mutableManagedUserGroup = mutableManagedUserGroup else {
                    response.status(.notFound)
                    next()
                    return
                }
                
                do {
                    try desiredUserGroupFromAdminAPI.update(mutableManagedUserGroup: mutableManagedUserGroup)
                } catch {
                    response.status(.badRequest)
                    next()
                    return
                }
                self.dataProvider.storeChangeFrom(mutableManagedObject: mutableManagedUserGroup, completion: { (managedUserGroup, error) in
                    if let managedUserGroup = managedUserGroup {
                        let userForAdminAPI = UserGroupForAdminAPI(managedUserGroup: managedUserGroup)
                        
                        if let jsonData = try? JSONEncoder().encode(userForAdminAPI) {
                            response.headers.setType("json")
                            response.send(data: jsonData)
                            response.status(.OK)
                            next()
                            return
                        } else {
                            response.status(.internalServerError)
                            next()
                            return
                        }
                        
                    } else {
                        response.status(.internalServerError)
                        next()
                        return
                    }
                })
            }
        } else {
            response.status(.internalServerError)
            next()
            return
        }
    }
    
    func deleteUserGroup(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let contentType = request.headers["Content-Type"] else {
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard contentType.hasPrefix("application/json") else {
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard let recordUUID = request.parameters["uuid"] else {
            response.status(.badRequest)
            next()
            return
        }
        
        dataProvider.completeManagedObject(ofType: ManagedUserGroup.self, withUUID: recordUUID) { (managedUserGroup, error) in
            if let managedUserGroup = managedUserGroup {
                self.dataProvider.delete(managedObject: managedUserGroup, completion: { (error) in
                    if error != nil {
                        response.status(.internalServerError)
                        next()
                        return
                    } else {
                        if let jsonData = try? JSONEncoder().encode([String:String]()) {
                            response.headers.setType("json")
                            response.send(data: jsonData)
                        }
                        
                        response.status(.OK)
                        next()
                        return
                    }
                })
            } else {
                response.status(.notFound)
                next()
                return
            }
        }
    }
    
    func createUserGroup(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let contentType = request.headers["Content-Type"] else {
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard contentType.hasPrefix("application/json") else {
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        if let desiredUserGroupFromAdminAPI = try? request.read(as: DesiredUserGroupFromAdminAPI.self) {
            
            desiredUserGroupFromAdminAPI.createNewMutableManagedUserGroup(withDataProvider: dataProvider) { (mutableManagedUserGroup) in
                guard let mutableManagedUserGroup = mutableManagedUserGroup else {
                    response.status(.badRequest)
                    next()
                    return
                }
                
                self.dataProvider.insert(mutableManagedObject: mutableManagedUserGroup, completion: { (managedUserGroup, error) in
                    if let managedUserGroup = managedUserGroup {
                        let userForAdminAPI = UserGroupForAdminAPI(managedUserGroup: managedUserGroup)
                        
                        if let jsonData = try? JSONEncoder().encode(userForAdminAPI) {
                            response.headers.setType("json")
                            response.send(data: jsonData)
                            response.status(.OK)
                            next()
                            return
                        } else {
                            response.status(.internalServerError)
                            next()
                            return
                        }
                        
                    } else {
                        response.status(.internalServerError)
                        next()
                        return
                    }
                })
            }
        } else {
            response.status(.internalServerError)
            next()
            return
        }
    }
}
