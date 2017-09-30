//
//  MunkiAPICatalogsHandler.swift
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

//class MunkiAPICatalogsHandler: DataProvider.SimpleHandler {
//    let apiNameForMultipleDocuments = "catalogs"
//    let apiNameForSingleDocument = "catalog"
//    let databaseViewForAllDocuments = "all_munki_catalogs"
//    let mandatoryKeysInSummary = ["uuid", "path", "name"]
//    let optionalKeysInSummary = [String]()
//    
//    let database: Database
//    
//    required init(database: Database) {
//        self.database = database
//    }
//    
//    func managedObjectFromJSONDocument(document: JSON) throws -> ManagedObject {
//        return try ManagedMunkiItem(databaseRecord: document)
//    }
//    
//}
