//
//  MunkiServer.swift
//  EasyLogin
//
//  Created by Yoann Gini on 29/09/2017.
//
//

import Foundation
import CouchDB
import Kitura

public class MunkiServer {
    let apiItemsHandler: MunkiAPIItemsHandler
//    let apiManifestsHandler: MunkiAPIManifestsHandler
//    let apiCatalogsHandler: MunkiAPICatalogsHandler
    
    public init(database: Database) {
        apiItemsHandler = MunkiAPIItemsHandler(database: database)
//        apiManifestsHandler = MunkiAPIManifestsHandler(database: database)
//        apiCatalogsHandler = MunkiAPICatalogsHandler(database: database)
    }
    
    public func router() -> Router {
        let apiRouter = Router()
        let repoRouter = Router()
        
        apiItemsHandler.installHandlers(to: apiRouter)
//        apiManifestsHandler.installHandlers(to: apiRouter)
//        apiCatalogsHandler.installHandlers(to: apiRouter)
        
        let router = Router()
        router.all("/api", middleware: apiRouter)
        router.all("/repo", middleware: repoRouter)
        return router
    }
}
