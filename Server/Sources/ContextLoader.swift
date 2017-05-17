//
//  ContextLoader.swift
//  EasyLogin
//
//  Created by Frank on 30/04/17.
//
//

import Kitura
import LoggerAPI

struct ContextLoader : RouterMiddleware {
    let databaseRegistry: DatabaseRegistry
    
    public func handle(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        defer { next() }
        Log.info("Request = \(request.urlURL) for route \(request.route)")
        // extract prefix (-> directory -> database name) and suffix (-> query) from URL and headers
        let context = DirectoryContext(database: databaseRegistry.database(name: "ground_control"))
        request.userInfo["EasyLoginContext"] = context
    }
}
