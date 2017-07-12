//
//  InitError.swift
//  EasyLogin
//
//  Created by Frank on 30/05/17.
//
//

import Foundation
import Kitura
import LoggerAPI

extension Router {
    public func installInitErrorHandlers() {
        self.get("/", handler: initErrorHandler)
    }
}

fileprivate func initErrorHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
    defer { next() }
    response.send("The application is running, but initialization failed.")
}

