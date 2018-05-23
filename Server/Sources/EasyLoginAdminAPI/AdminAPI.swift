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
import LoggerAPI

enum AdminAPIError: Error {
    case missingField
}

public class AdminAPI {
    let dataProvider: DataProvider
    let usersAPI: AdminAPIUsers
    let userGroupsAPI: AdminAPIUserGroups
    
    public init(dataProvider: DataProvider) {
        self.dataProvider = dataProvider
        usersAPI = AdminAPIUsers(dataProvider: dataProvider)
        userGroupsAPI = AdminAPIUserGroups(dataProvider: dataProvider)
    }
    
    public func router() -> Router {
        Log.entry("Loading AdminAPI router")
        let router = Router()
        let options = Options(allowedOrigin: .all, methods: ["GET","PUT", "POST", "DELETE"], allowedHeaders: ["X-Total-Count", "Content-Type"], maxAge: 5, exposedHeaders: ["X-Total-Count", "Content-Type"])
        let cors = CORS(options: options)
        router.all("/*", middleware: cors)
        
        usersAPI.setupRouter(router)
        userGroupsAPI.setupRouter(router)
        Log.exit("Loading AdminAPI router")
        return router
    }
}
