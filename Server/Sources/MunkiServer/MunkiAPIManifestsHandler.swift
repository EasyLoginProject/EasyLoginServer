//
//  MunkiAPIManifestsHandler.swift
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

//class MunkiAPIManifestsHandler: DataProvider.SimpleHandler {
//    let apiNameForMultipleDocuments = "manifests"
//    let apiNameForSingleDocument = "manifest"
//    let databaseViewForAllDocuments = "all_munki_manifests"
//    let mandatoryKeysInSummary = ["uuid", "name"]
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
