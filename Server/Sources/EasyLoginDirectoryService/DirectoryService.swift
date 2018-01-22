//
//  DirectoryService.swift
//  EasyLogin
//
//  Created by Frank on 18/06/17.
//
//

import Foundation
import CouchDB
import Kitura
import DataProvider

public class EasyLoginDirectoryService {
    let users: Users
    let devices: Devices
    let usergroups: UserGroups
    
    public init(database: Database, dataProvider: DataProvider) {
        users = Users(database: database)
        devices = Devices(database: database)
        usergroups = UserGroups(database: database, dataProvider: dataProvider)
    }
    
    public func router() -> Router {
        let router = Router()
        router.post(middleware:BodyParser())
        router.put(middleware:BodyParser())
        users.installHandlers(to: router)
        devices.installHandlers(to: router)
        usergroups.installHandlers(to: router)
        return router
    }
}
