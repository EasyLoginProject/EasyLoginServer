//
//  AbstractHandler.swift
//  EasyLogin
//
//  Created by Yoann Gini on 29/09/2017.
//
//

import Foundation
import CouchDB
import Kitura

public protocol AbstractHandler {
    init(database: Database)
    func installHandlers(to router: Router)
}

