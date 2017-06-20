//
//  DatabaseDevices.swift
//  EasyLogin
//
//  Created by Frank on 20/06/17.
//
//

import Foundation
import CouchDB
import Kitura
import LoggerAPI
import SwiftyJSON

enum DevicesError: Error {
    case databaseFailure
}

extension Router {
    public func installDatabaseDevicesHandlers() {
        self.get("/db/devices", handler: listDevicesHandler)
        self.get("/db/devices/:uuid", handler: getDeviceHandler)
        self.post("/db/devices", handler: createDeviceHandler)
    }
}

fileprivate func getDeviceHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
    defer { next() }
    guard let uuid = request.parameters["uuid"] else {
        sendError(.missingField("uuid"), to:response)
        return
    }
    guard let database = database else {
        sendError(to: response)
        return
    }
    database.retrieve(uuid, callback: { (document: JSON?, error: NSError?) in
        guard let document = document else {
            sendError(.notFound, to: response)
            return
        }
        guard let retrievedDevice = ManagedDevice(databaseRecord:document) else {
            sendError(to: response)
            return
        }
        response.send(json: retrievedDevice.responseElement())
    })
}

fileprivate func createDeviceHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
    defer { next() }
    guard let parsedBody = request.body else {
        Log.error("body parsing failure")
        sendError(to:response)
        return
    }
    switch(parsedBody) {
    case .json(let jsonBody):
        guard let device = ManagedDevice(requestElement:jsonBody) else {
            sendError(.debug("ManagedDevice creation"), to: response)
            return
        }
        guard let database = database else {
            sendError(.databaseNotAvailable, to: response)
            return
        }
        insert(device, into: database) {
            createdDevice in
            guard let createdDevice = createdDevice else {
                sendError(.debug("Insert"), to: response)
                return
            }
            response.statusCode = .created
            response.headers.setLocation("/db/devices/\(createdDevice.uuid)")
            response.send(json: createdDevice.responseElement())
        }
    default:
        sendError(to: response)
    }
}

fileprivate func listDevicesHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
    defer { next() }
    guard let database = database else {
        sendError(to: response)
        return
    }
    database.queryByView("all_devices", ofDesign: "main_design", usingParameters: []) { (databaseResponse, error) in
        guard let databaseResponse = databaseResponse else {
            sendError(to: response)
            return
        }
        let deviceList = databaseResponse["rows"].array?.flatMap { device -> [String:Any]? in
            if let uuid = device["value"]["uuid"].string,
                let serialNumber = device["value"]["serialNumber"].string,
                let deviceName = device["value"]["deviceName"].string {
                return ["uuid":uuid, "serialNumber":serialNumber, "deviceName":deviceName]
            }
            return nil
        }
        let result = ["devices": deviceList ?? []]
        response.send(json: JSON(result))
    }
}

fileprivate func insert(_ device: ManagedDevice, into database: Database, completion: @escaping (ManagedDevice?) -> Void) -> Void {
    let document = JSON(device.databaseRecord())
    database.create(document, callback: { (id: String?, rev: String?, createdDocument: JSON?, error: NSError?) in
        guard createdDocument != nil else {
            Log.error("Create device: \(error)")
            completion(nil)
            return
        }
        let createdDevice = ManagedDevice(databaseRecord:document)
        completion(createdDevice)
    })
}

