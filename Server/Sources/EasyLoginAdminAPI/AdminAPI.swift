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

struct UserForAdminAPI: Codable {
    let uuid: String
    
    let numericID: Int
    let shortname: String
    let principalName: String
    let email: String?
    let givenName: String?
    let surname: String?
    let fullName: String?
    let clearTextPassword: String?
    
    enum CodingKeys: String, CodingKey {
        case uuid = "id"
        case numericID
        case shortname
        case principalName
        case email
        case givenName
        case surname
        case fullName
        case clearTextPassword
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
        clearTextPassword = nil
    }
}

public class AdminAPI {
    let dataProvider: DataProvider
    
    public init() throws {
        dataProvider = try DataProvider.singleton()
    }
    
    public func router() -> Router {
        let router = Router()
        let options = Options(allowedOrigin: .all, methods: ["GET","PUT"], allowedHeaders: ["X-Total-Count", "Content-Type"], maxAge: 5)
        let cors = CORS(options: options)
        router.all("/*", middleware: cors)
        
        router.get("/users", handler: getUsers)
        
        return router
    }
    
    func getUsers(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
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
                        case .clearTextPassword:
                            return false
                        }
                    })
                }
            }
            
            
            let sortKey: UserForAdminAPI.CodingKeys
            if let sortField = request.queryParameters["_sort"] {
                if let requestedSortKey = UserForAdminAPI.CodingKeys(stringValue: sortField) {
                    sortKey = requestedSortKey
                } else {
                    sortKey = .uuid
                }
            } else {
                sortKey = .uuid
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
                default:
                    isAscendent = left.numericID < right.numericID
                }
                
                if ascending {
                    return isAscendent
                } else {
                    return !isAscendent
                }
            })
            
            let first: Int
            if let startValue = request.queryParameters["_start"], let start = Int(startValue), start >= 0 {
                first = start
            } else {
                first = 0
            }
            
            let last: Int
            if let endValue = request.queryParameters["_end"], let end = Int(endValue), end < managedUsers.count {
                last = end
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
}
