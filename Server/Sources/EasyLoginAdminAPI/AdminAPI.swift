//
//  AdminAPI.swift
//  EasyLoginAdminAPI
//
//  Created by Yoann Gini on 01/01/2018.
//

import Foundation
import DataProvider
import Kitura
import KituraCORS

enum AdminAPIError: Error {
    case missingField
}

struct DesiredUserFromAdminAPI: Codable {
    let shortname: String?
    let principalName: String?
    let email: String?
    let givenName: String?
    let surname: String?
    let fullName: String?
    let clearTextPassword: String?
    
    func update(mutableManagedUser:MutableManagedUser) throws {
        if let shortname = shortname {
            try mutableManagedUser.setShortname(shortname)
        }
        if let principalName = principalName {
            try mutableManagedUser.setPrincipalName(principalName)
        }
        if let email = email {
            try mutableManagedUser.setEmail(email)
        }
        if let givenName = givenName {
            try mutableManagedUser.setGivenName(givenName)
        }
        if let surname = surname {
            try mutableManagedUser.setSurname(surname)
        }
        if let fullName = fullName {
            try mutableManagedUser.setFullName(fullName)
        }
        if let clearTextPassword = clearTextPassword {
            try mutableManagedUser.setClearTextPasssword(clearTextPassword)
        }
    }
    
    func createNewMutableManagedUser(withDataProvider dataProvider:DataProvider, completion: @escaping (MutableManagedUser?) -> Void) {
        if let shortname = shortname, let principalName = principalName, let clearTextPassword = clearTextPassword {
            let numericIDGenerator = dataProvider.persistentCounter(name: "users.numericID")
            numericIDGenerator.nextValue(completion: { (numericID) in
                if let numericID = numericID {
                    let newUser = MutableManagedUser(withDataProvider: dataProvider, numericID: numericID, shortname: shortname, principalName: principalName, email: self.email, givenName: self.givenName, surname: self.surname, fullName: self.fullName)
                    do {
                        try newUser.setClearTextPasssword(clearTextPassword)
                        completion(newUser)
                    } catch {
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            })
            
        } else {
            completion(nil)
        }
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
    
    enum CodingKeys: String, CodingKey {
        case uuid = "id"
        case numericID
        case shortname
        case principalName
        case email
        case givenName
        case surname
        case fullName
    }
    
    init(managedUser: ManagedUser) {
        uuid = managedUser.uuid
        numericID = managedUser.numericID
        shortname = managedUser.shortname
        principalName = managedUser.principalName
        email = managedUser.email
        givenName = managedUser.givenName
        surname = managedUser.surname
        fullName = managedUser.fullName
    }
}

public class AdminAPI {
    let dataProvider: DataProvider
    
    public init(dataProvider: DataProvider) {
        self.dataProvider = dataProvider
    }
    
    public func router() -> Router {
        let router = Router()
        let options = Options(allowedOrigin: .all, methods: ["GET","PUT", "POST", "DELETE"], allowedHeaders: ["X-Total-Count", "Content-Type"], maxAge: 5, exposedHeaders: ["X-Total-Count", "Content-Type"])
        let cors = CORS(options: options)
        router.all("/*", middleware: cors)
        
        router.get("/users", handler: getUsers)
        router.post("/users", handler: createUser)
        router.get("/users/:uuid", handler: getUser)
        router.put("/users/:uuid", handler: updateUser)
        router.delete("/users/:uuid", handler: deleteUser)
        
        return router
    }
    
    func getUsers(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {        
        dataProvider.completeManagedObjects(ofType: ManagedUser.self) { (managedUsers, error) in
            guard var managedUsers = managedUsers else {
                response.status(.internalServerError)
                next()
                return
            }
            
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
                        }
                    })
                }
            }
            
            
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
                }
                
                if ascending {
                    return isAscendent
                } else {
                    return !isAscendent
                }
            })
            
            guard managedUsers.count != 0 else {
                if let jsonData = try? JSONEncoder().encode([String]()) {
                    response.headers.append("X-Total-Count", value: String(managedUsers.count))
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
            if let endValue = request.queryParameters["_end"], let end = Int(endValue), end-1 < managedUsers.count {
                last = end-1
            } else {
                last = managedUsers.count - 1
            }
            
            var selectedUsers = [UserForAdminAPI]()
            
            for index in first...last {
                selectedUsers.append(UserForAdminAPI(managedUser: managedUsers[index]))
            }
            
            if let jsonData = try? JSONEncoder().encode(selectedUsers) {
                response.headers.append("X-Total-Count", value: String(managedUsers.count))
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
    
    func getUser(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let recordUUID = request.parameters["uuid"] else {
            response.status(.badRequest)
            next()
            return
        }
        
        dataProvider.completeManagedObject(ofType: ManagedUser.self, withUUID: recordUUID) { (managedUser, error) in
            guard let managedUser = managedUser else {
                response.status(.notFound)
                next()
                return
            }
            
            let userForAdminAPI = UserForAdminAPI(managedUser: managedUser)
            
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
    
    func updateUser(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
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
        
        if let desiredUserFromAdminAPI = try? request.read(as: DesiredUserFromAdminAPI.self) {
            dataProvider.completeManagedObject(ofType: MutableManagedUser.self, withUUID: recordUUID) { (mutableManagedUser, error) in
                guard let mutableManagedUser = mutableManagedUser else {
                    response.status(.notFound)
                    next()
                    return
                }
                
                do {
                    try desiredUserFromAdminAPI.update(mutableManagedUser: mutableManagedUser)
                } catch {
                    response.status(.badRequest)
                    next()
                    return
                }
                self.dataProvider.storeChangeFrom(mutableManagedObject: mutableManagedUser, completion: { (managedUser, error) in
                    if let managedUser = managedUser {
                        let userForAdminAPI = UserForAdminAPI(managedUser: managedUser)
                        
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
    
    func deleteUser(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
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
        
        dataProvider.completeManagedObject(ofType: ManagedUser.self, withUUID: recordUUID) { (managedUser, error) in
            if let managedUser = managedUser {
                self.dataProvider.delete(managedObject: managedUser, completion: { (error) in
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
    
    func createUser(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
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
        
        if let desiredUserFromAdminAPI = try? request.read(as: DesiredUserFromAdminAPI.self) {
            
            desiredUserFromAdminAPI.createNewMutableManagedUser(withDataProvider: dataProvider) { (mutableManagedUser) in
                guard let mutableManagedUser = mutableManagedUser else {
                    response.status(.badRequest)
                    next()
                    return
                }
                
                self.dataProvider.insert(mutableManagedObject: mutableManagedUser, completion: { (managedUser, error) in
                    if let managedUser = managedUser {
                        let userForAdminAPI = UserForAdminAPI(managedUser: managedUser)
                        
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
