//
//  MunkiAPIItemsHandler.swift
//  EasyLogin
//
//  Created by Yoann Gini on 29/09/2017.
//
//

import Foundation
import CouchDB
import Kitura
import LoggerAPI
import SwiftyJSON
import Extensions
import NotificationService
import DataProvider

class MunkiAPIItemsHandler: DataProvider.SimpleHandler {
    let apiNameForMultipleDocuments = "items"
    let apiNameForSingleDocument = "item"
    let databaseViewForAllDocuments = "all_munki_items"
    let mandatoryKeysInSummary = ["path", "name", "display_name", "version"]
    let optionalKeysInSummary = [String]()
    
    let database: Database
    
    required init(database: Database) {
        self.database = database
    }

    func managedObjectFromJSONDocument(document: JSON) throws -> ManagedObject {
        return try ManagedMunkiItem(databaseRecord: document)
    }
}
