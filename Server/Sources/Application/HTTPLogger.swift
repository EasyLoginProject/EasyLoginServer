//
//  HTTPLogger.swift
//  EasyLoginServer
//
//  Created by Frank on 20/06/17.
//
//

import Foundation
import Kitura

public class HTTPLogger: TextOutputStream {
    var logText: String
    
    init() {
        logText = ""
    }
    
    public func write(_ string: String) {
        logText.append(string)
    }
}

public extension HTTPLogger {
    public func installHandler(to router: Router) {
        router.get("/getlogs") { request, response, next in
            defer { next() }
            response.send(self.logText)
            self.logText = ""
        }
    }
}
