//
//  SimpleHandler.swift
//  EasyLogin
//
//  Created by Yoann Gini on 30/09/2017.
//
//

import Foundation
import CouchDB
import Kitura
import LoggerAPI
import SwiftyJSON
import Extensions
import NotificationService

public protocol SimpleHandler : AbstractHandler {
    var database: Database {get}
    
    var databaseViewForAllDocuments: String {get}
    
    var apiNameForSingleDocument: String {get}
    var apiNameForMultipleDocuments: String {get}
    
    var mandatoryKeysInSummary: [String] {get}
    var optionalKeysInSummary: [String] {get}
    
    func managedObjectFromJSONDocument(document: JSON) throws -> ManagedObject
}

public extension SimpleHandler {
    func installHandlers(to router: Router) {
        router.get("/"+apiNameForMultipleDocuments, handler: listAllDocuments)
        router.get("/"+apiNameForMultipleDocuments+"/:document_id*", handler: getRequestedDocument)
    }
    
    func resumeDocumentForListingPurpose(document: JSON) -> Any? {
        var documentSummary = [String:Any]()
        for mandatoryKey in mandatoryKeysInSummary {
            if let value = document["value"][mandatoryKey].string {
                documentSummary[mandatoryKey] = value
            } else {
                return nil
            }
        }
        
        for optionalKey in optionalKeysInSummary {
            if let value = document["value"][optionalKey].string {
                documentSummary[optionalKey] = value
            }
        }
        
        if documentSummary.count == 0 {
            return nil
        }
        
        return documentSummary
    }
    
    func listAllDocuments(request: RouterRequest, response: RouterResponse, next: @escaping()->Void) -> Void {
        database.queryByView(databaseViewForAllDocuments, ofDesign: "main_design", usingParameters: []) { (databaseResponse, error) in
            defer { next() }
            
            guard let databaseResponse = databaseResponse else {
                let errorMessage = error?.localizedDescription ?? "error is nil"
                sendError(.debug("Database request failed: \(errorMessage)"), to: response)
                return
            }
            
            let allDocuments = databaseResponse["rows"].array?.flatMap { document -> Any? in
                return self.resumeDocumentForListingPurpose(document: document)
            }
            
            let result = [self.apiNameForMultipleDocuments: allDocuments ?? []]
            response.send(json: JSON(result))
        }
    }
    
    func getRequestedDocument(request: RouterRequest, response: RouterResponse, next: @escaping ()->Void) -> Void {
        guard let document_id = request.parameters["document_id"] else {
            sendError(.missingField("document_id"), to:response)
            next()
            return
        }
        
        database.retrieve(document_id, callback: { (document: JSON?, error: NSError?) in
            defer { next() }
            
            guard let document = document else {
                sendError(.notFound, to: response)
                return
            }
            
            do {
                let managedObject = try self.managedObjectFromJSONDocument(document: document)
                response.send(json: try managedObject.responseElement())
            }
            catch let error as EasyLoginError {
                sendError(error, to: response)
            }
            catch {
                sendError(.debug("Internal error"), to: response)
            }
        })
    }
}
