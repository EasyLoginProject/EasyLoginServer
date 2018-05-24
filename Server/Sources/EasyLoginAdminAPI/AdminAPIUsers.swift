//
//  AdminAPIUsers.swift
//  EasyLoginAdminAPI
//
//  Created by Yoann Gini on 01/02/2018.
//

import Foundation
import DataProvider
import Kitura
import Dispatch
import LoggerAPI

struct DesiredUserFromAdminAPI: Codable {
    let shortname: String?
    let principalName: String?
    let email: String?
    let givenName: String?
    let surname: String?
    let fullName: String?
    let clearTextPassword: String?
    
    let memberOf: [String]?
    
    func update(mutableManagedUser:MutableManagedUser) throws {
        Log.entry("Updating mutableManagedUser with informations from Admin API")
        if let shortname = shortname {
            Log.debug("Updating user shortname")
            try mutableManagedUser.setShortname(shortname)
        }
        if let principalName = principalName {
            Log.debug("Updating user principalName")
            try mutableManagedUser.setPrincipalName(principalName)
        }
        if let email = email {
            Log.debug("Updating user e-mail")
            try mutableManagedUser.setEmail(email)
        }
        if let givenName = givenName {
            mutableManagedUser.setGivenName(givenName)
        }
        if let surname = surname {
            mutableManagedUser.setSurname(surname)
        }
        if let fullName = fullName {
            mutableManagedUser.setFullName(fullName)
        }
        if let clearTextPassword = clearTextPassword {
            Log.debug("Updating user password")
            try mutableManagedUser.setClearTextPasssword(clearTextPassword)
        }
        
        if let memberOf = memberOf {
            Log.verbose("Checking memberOf list for valid groups")
            let validParentGroupIDs = memberOf.compactMap({ (requestedPartentGroupUUID) -> ManagedObjectRecordID? in
                Log.verbose("Checking group existence for \(requestedPartentGroupUUID)")
                var finalRecordID: ManagedObjectRecordID? = nil
                let semaphore = DispatchSemaphore(value: 0)
                mutableManagedUser.dataProvider!.managedObjectRecordID(forObjectOfType: ManagedUserGroup.self, withSupposedUUID: requestedPartentGroupUUID, completion: { (recordID, error) in
                    Log.verbose("Group found")
                    finalRecordID = recordID
                    semaphore.signal()
                })
                semaphore.wait()
                return finalRecordID
            })
            
            let semaphore = DispatchSemaphore(value: 0)
            Log.entry("Updating mutableManagedUser relationship")
            mutableManagedUser.setRelationships(memberOf: validParentGroupIDs, completion: { (error) in
                Log.verbose("Relationship update done with error: \(String(describing: error))")
                semaphore.signal()
            })
            semaphore.wait()
            Log.exit("Updating mutableManagedUser relationship")
        }
        Log.exit("Updating mutableManagedUser with informations from Admin API")
    }
    
    func createNewMutableManagedUser(withDataProvider dataProvider:DataProvider, completion: @escaping (MutableManagedUser?) -> Void) {
        Log.entry("Creating new mutableManagedUser")
        if let shortname = shortname, let principalName = principalName, let clearTextPassword = clearTextPassword {
            Log.verbose("Request valid, looking for a new numericID")
            let numericIDGenerator = dataProvider.persistentCounter(name: "users.numericID")
            numericIDGenerator.nextValue(completion: { (numericID) in
                if let numericID = numericID {
                    Log.verbose("Got a numericID, creating the user")
                    let newUser = MutableManagedUser(withDataProvider: dataProvider, numericID: numericID, shortname: shortname, principalName: principalName, email: self.email, givenName: self.givenName, surname: self.surname, fullName: self.fullName)
                    do {
                        Log.debug("User created with success, updating password")
                        try newUser.setClearTextPasssword(clearTextPassword)
                        Log.debug("Password updated")
                        completion(newUser)
                    } catch {
                        Log.error("Unable to update new user password")
                        completion(nil)
                    }
                } else {
                    Log.error("Unable to get new numericID")
                    completion(nil)
                }
            })
            
        } else {
            Log.error("Not a valid object for creating new user")
            completion(nil)
        }
        Log.exit("Creating new mutableManagedUser")
    }
}

struct UserForAdminAPI: Codable {
    let uuid: String
    
    let numericID: Int
    let shortname: String
    let principalName: String
    let email: String?
    let givenName: String?
    let surname: String?
    let fullName: String?
    
    let memberOf: [String]
    
    enum CodingKeys: String, CodingKey {
        case uuid = "id"
        case numericID
        case shortname
        case principalName
        case email
        case givenName
        case surname
        case fullName
        case memberOf
    }
    
    init(managedUser: ManagedUser) {
        Log.entry("Creating user representation for Admin API")
        uuid = managedUser.uuid
        numericID = managedUser.numericID
        shortname = managedUser.shortname
        principalName = managedUser.principalName
        email = managedUser.email
        givenName = managedUser.givenName
        surname = managedUser.surname
        fullName = managedUser.fullName
        memberOf = managedUser.memberOf
        Log.exit("Creating user representation for Admin API")
    }
}

public class AdminAPIUsers {
    let dataProvider: DataProvider
    
    public init(dataProvider: DataProvider) {
        self.dataProvider = dataProvider
    }
    
    public func setupRouter(_ router:Router) {        
        router.get("/users", handler: getUsers)
        router.post("/users", handler: createUser)
        router.get("/users/:uuid", handler: getUser)
        router.put("/users/:uuid", handler: updateUser)
        router.delete("/users/:uuid", handler: deleteUser)
    }
    
    func getUsers(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        Log.entry("Get list of all users")
        dataProvider.completeManagedObjects(ofType: ManagedUser.self) { (managedUsers, error) in
            guard var managedUsers = managedUsers else {
                Log.error("No managedUsers found: \(String(describing: error))")
                response.status(.internalServerError)
                next()
                return
            }
            
            Log.verbose("Filtering user list with per field queryParameters")
            for (param, value) in request.queryParameters where !param.hasPrefix("_") {
                if let key = UserForAdminAPI.CodingKeys(stringValue: param) {
                    managedUsers = managedUsers.filter({ (managedUser) -> Bool in
                        switch key {
                        case .uuid:
                            return managedUser.uuid.contains(value)
                        case .shortname:
                            return managedUser.shortname.contains(value)
                        case .principalName:
                            return managedUser.principalName.contains(value)
                        case .email:
                            if let email = managedUser.email {
                                return email.contains(value)
                            } else {
                                return false
                            }
                        case .givenName:
                            if let givenName = managedUser.givenName {
                                return givenName.contains(value)
                            } else {
                                return false
                            }
                        case .surname:
                            if let surname = managedUser.surname {
                                return surname.contains(value)
                            } else {
                                return false
                            }
                        case .fullName:
                            if let fullName = managedUser.fullName {
                                return fullName.contains(value)
                            } else {
                                return false
                            }
                        case .numericID:
                            return String(managedUser.numericID).contains(value)
                        case .memberOf:
                            return false
                        }
                    })
                }
            }
            
            Log.verbose("Filtering user list with global queryParameters")
            if let globalQuery = request.queryParameters["q"] {
                let globalQuery = globalQuery.lowercased()
                managedUsers = managedUsers.filter({ (managedUser) -> Bool in
                    if managedUser.shortname.lowercased().contains(globalQuery) {
                        return true
                    } else if managedUser.principalName.lowercased().contains(globalQuery) {
                        return true
                    } else if let givenName = managedUser.givenName, givenName.lowercased().contains(globalQuery) {
                        return true
                    } else if let surname = managedUser.surname, surname.lowercased().contains(globalQuery) {
                        return true
                    } else if let fullName = managedUser.fullName, fullName.lowercased().contains(globalQuery) {
                        return true
                    } else {
                        return false
                    }
                })
            }
            
            Log.verbose("Sorting request result")
            let sortKey: UserForAdminAPI.CodingKeys
            if let sortField = request.queryParameters["_sort"] {
                if let requestedSortKey = UserForAdminAPI.CodingKeys(stringValue: sortField) {
                    sortKey = requestedSortKey
                } else {
                    sortKey = .shortname
                }
            } else {
                sortKey = .shortname
            }
            
            Log.verbose("Ordering request result")
            let ascending: Bool
            if let orderField = request.queryParameters["_order"] {
                ascending = orderField == "ASC"
            } else {
                ascending = true
            }
            
            managedUsers.sort(by: { (left, right) -> Bool in
                let isAscendent: Bool
                switch sortKey {
                case .uuid:
                    isAscendent = left.uuid < right.uuid
                case .shortname:
                    isAscendent = left.shortname < right.shortname
                case .principalName:
                    isAscendent = left.principalName < right.principalName
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
                case .givenName:
                    if let lv = left.givenName, let rv = right.givenName {
                        isAscendent = lv < rv
                    } else if let _ = right.givenName {
                        isAscendent = true
                    } else if let _ = left.givenName {
                        isAscendent = false
                    } else {
                        isAscendent = left.numericID < right.numericID
                    }
                case .surname:
                    if let lv = left.surname, let rv = right.surname {
                        isAscendent = lv < rv
                    } else if let _ = right.surname {
                        isAscendent = true
                    } else if let _ = left.surname {
                        isAscendent = false
                    } else {
                        isAscendent = left.numericID < right.numericID
                    }
                case .fullName:
                    if let lv = left.fullName, let rv = right.fullName {
                        isAscendent = lv < rv
                    } else if let _ = right.fullName {
                        isAscendent = true
                    } else if let _ = left.fullName {
                        isAscendent = false
                    } else {
                        isAscendent = left.numericID < right.numericID
                    }
                case .numericID:
                    isAscendent = left.numericID < right.numericID
                case .memberOf:
                    isAscendent = left.memberOf.count < right.memberOf.count
                }
                
                if ascending {
                    return isAscendent
                } else {
                    return !isAscendent
                }
            })
            
            guard managedUsers.count != 0 else {
                Log.verbose("No records found, sending empty result")
                if let jsonData = try? JSONEncoder().encode([String]()) {
                    response.headers.append("X-Total-Count", value: "0")
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
            
            Log.verbose("Extracting requested records subset (pagination)")
            let first: Int
            if let startValue = request.queryParameters["_start"], let start = Int(startValue), start >= 0 {
                first = start
            } else {
                first = 0
            }
            
            let last: Int
            if let endValue = request.queryParameters["_end"], let end = Int(endValue), end-1 < managedUsers.count {
                last = end-1
            } else {
                last = managedUsers.count - 1
            }
            
            var selectedUsers = [UserForAdminAPI]()
            
            for index in first...last {
                selectedUsers.append(UserForAdminAPI(managedUser: managedUsers[index]))
            }
            
            Log.verbose("Sending selected records")
            if let jsonData = try? JSONEncoder().encode(selectedUsers) {
                response.headers.append("X-Total-Count", value: String(managedUsers.count))
                response.headers.setType("json")
                response.send(data: jsonData)
                response.status(.OK)
                next()
                return
            } else {
                Log.error("Unable to handle JSON encoding")
                response.status(.internalServerError)
                next()
                return
            }
        }
        Log.exit("Get list of all users")
    }
    
    func getUser(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        Log.entry("Specfic user requested")
        guard let recordUUID = request.parameters["uuid"] else {
            Log.error("No UUID provided")
            response.status(.badRequest)
            next()
            return
        }
        
        dataProvider.completeManagedObject(ofType: ManagedUser.self, withUUID: recordUUID) { (managedUser, error) in
            guard let managedUser = managedUser else {
                Log.error("UUID not found, \(String(describing: error))")
                response.status(.notFound)
                next()
                return
            }
            
            Log.verbose("Encoding managedUser for Admin API")
            let userForAdminAPI = UserForAdminAPI(managedUser: managedUser)
            
            if let jsonData = try? JSONEncoder().encode(userForAdminAPI) {
                Log.verbose("Sending encoded record")
                response.headers.setType("json")
                response.send(data: jsonData)
                response.status(.OK)
                next()
                return
            } else {
                Log.error("Unable to encode result for Admin API")
                response.status(.internalServerError)
                next()
                return
            }
        }
        Log.exit("Specfic user requested")
    }
    
    func updateUser(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        Log.entry("User update requested")
        guard let contentType = request.headers["Content-Type"] else {
            Log.error("No content type specified")
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard contentType.hasPrefix("application/json") else {
            Log.error("Unsupported content type")
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard let recordUUID = request.parameters["uuid"] else {
            Log.error("No UUID specificed")
            response.status(.badRequest)
            next()
            return
        }
        
        if let desiredUserFromAdminAPI = try? request.read(as: DesiredUserFromAdminAPI.self) {
            Log.verbose("Request decoded, looking for related mutableManagedUser")
            dataProvider.completeManagedObject(ofType: MutableManagedUser.self, withUUID: recordUUID) { (mutableManagedUser, error) in
                guard let mutableManagedUser = mutableManagedUser else {
                    Log.debug("Requested mutableManagedUser not found")
                    response.status(.notFound)
                    next()
                    return
                }
                
                do {
                    Log.verbose("Validating the update request")
                    try desiredUserFromAdminAPI.update(mutableManagedUser: mutableManagedUser)
                    Log.verbose("Update accepted")
                } catch {
                    Log.error("Invalid update request")
                    response.status(.badRequest)
                    next()
                    return
                }
                Log.verbose("Storing updated object")
                self.dataProvider.storeChangeFrom(mutableManagedObject: mutableManagedUser, completion: { (managedUser, error) in
                    if let managedUser = managedUser {
                        Log.verbose("Update done with success, returning updated record")
                        let userForAdminAPI = UserForAdminAPI(managedUser: managedUser)
                        
                        if let jsonData = try? JSONEncoder().encode(userForAdminAPI) {
                            response.headers.setType("json")
                            response.send(data: jsonData)
                            response.status(.OK)
                            next()
                            return
                        } else {
                            Log.error("Error encoding updated record")
                            response.status(.internalServerError)
                            next()
                            return
                        }
                        
                    } else {
                        Log.error("Storing update failed: \(String(describing: error))")
                        response.status(.internalServerError)
                        next()
                        return
                    }
                })
            }
        } else {
            Log.error("Unable to decode update request")
            response.status(.internalServerError)
            next()
            return
        }
        Log.exit("User update requested")
    }
    
    func deleteUser(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        Log.entry("User deletion requested")
        guard let contentType = request.headers["Content-Type"] else {
            Log.error("No content type specified")
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard contentType.hasPrefix("application/json") else {
            Log.error("Unsupported content type")
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard let recordUUID = request.parameters["uuid"] else {
            Log.error("No UUID specificed")
            response.status(.badRequest)
            next()
            return
        }
        
        Log.verbose("Retriving record to delete")
        dataProvider.completeManagedObject(ofType: ManagedUser.self, withUUID: recordUUID) { (managedUser, error) in
            if let managedUser = managedUser {
                Log.info("Deleting record")
                self.dataProvider.delete(managedObject: managedUser, completion: { (error) in
                    if error != nil {
                        Log.error("Unable to delete record:\(String(describing: error))")
                        response.status(.internalServerError)
                        next()
                        return
                    } else {
                        Log.info("Record deleted")
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
                Log.error("Record not found: \(String(describing:error))")
                response.status(.notFound)
                next()
                return
            }
        }
        Log.exit("User deletion requested")
    }
    
    func createUser(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        Log.entry("User creation requested")
        guard let contentType = request.headers["Content-Type"] else {
            Log.error("No content type specified")
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        guard contentType.hasPrefix("application/json") else {
            Log.error("Unsupported content type")
            response.status(.unsupportedMediaType)
            next()
            return
        }
        
        if let desiredUserFromAdminAPI = try? request.read(as: DesiredUserFromAdminAPI.self) {
            Log.info("Creation request decoded with success")
            desiredUserFromAdminAPI.createNewMutableManagedUser(withDataProvider: dataProvider) { (mutableManagedUser) in
                guard let mutableManagedUser = mutableManagedUser else {
                    Log.error("Failed to create user object")
                    response.status(.badRequest)
                    next()
                    return
                }
                
                Log.verbose("User object created, starting storing operation")
                self.dataProvider.insert(mutableManagedObject: mutableManagedUser, completion: { (managedUser, error) in
                    if let managedUser = managedUser {
                        Log.info("New user stored in database")
                        let userForAdminAPI = UserForAdminAPI(managedUser: managedUser)
                        
                        if let jsonData = try? JSONEncoder().encode(userForAdminAPI) {
                            Log.verbose("Returing created object")
                            response.headers.setType("json")
                            response.send(data: jsonData)
                            response.status(.OK)
                            next()
                            return
                        } else {
                            Log.error("Unable to encode created object")
                            response.status(.internalServerError)
                            next()
                            return
                        }
                        
                    } else {
                        Log.error("Failed to write user record: \(String(describing: error))")
                        response.status(.internalServerError)
                        next()
                        return
                    }
                })
            }
        } else {
            Log.error("Unable to decode creation request")
            response.status(.internalServerError)
            next()
            return
        }
        Log.exit("User creation requested")
    }
}
