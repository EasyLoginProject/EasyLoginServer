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
        users = Users(dataProvider: dataProvider)
        devices = Devices(database: database)
        usergroups = UserGroups(dataProvider: dataProvider)
    }
    
    public func router() -> Router {
        let router = Router()
        let parsingRouter = Router() // temporary -- required only for services not using ManagedObjectRepresentation yet
        parsingRouter.post(middleware:BodyParser())
        parsingRouter.put(middleware:BodyParser())
        users.installHandlers(to: router)
        devices.installHandlers(to: parsingRouter)
        usergroups.installHandlers(to: router)
        router.all(middleware: parsingRouter)
        return router
    }
}
