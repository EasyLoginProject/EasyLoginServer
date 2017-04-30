//
//  DatabaseRegistry.swift
//  GroundControl
//
//  Created by Frank on 27/04/2017.
//
//

import Foundation
import CouchDB
import LoggerAPI

struct DatabaseRegistry {
	let couchDBClient: CouchDBClient
	
	init() {
		let connectionProperties = ConnectionProperties(host: "127.0.0.1", port: 5984, secured: false)
		couchDBClient = CouchDBClient(connectionProperties: connectionProperties)
	}
	
	func createDatabase(name: String) -> Void {
		couchDBClient.createDB(name) { (database, error) in
			if database != nil {
				Log.info("Database '\(name)' created")
			}
			if let error = error {
				Log.error("Error \(error) while creating database '\(name)'")
			}
		}
	}
	
	func database(name: String) -> Database {
		let database = couchDBClient.database(name)
		return database
	}
}
