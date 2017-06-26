//
//  Devices.swift
//  EasyLoginServer
//
//  Created by Frank on 19/06/17.
//
//

import Foundation
import CouchDB
import Kitura
import LoggerAPI
import SwiftyJSON
import Extensions
import NotificationService

class Devices {
    let database: Database
    
    init(database: Database) {
        self.database = database
    }
    
    func installHandlers(to router: Router) {
        router.get("/devices", handler: listDevicesHandler)
        router.get("/devices/:uuid", handler: getDeviceHandler)
        router.post("/devices", handler: createDeviceHandler)
    }
    
    fileprivate func getDeviceHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        guard let uuid = request.parameters["uuid"] else {
            sendError(.missingField("uuid"), to:response)
            return
        }
        database.retrieve(uuid, callback: { (document: JSON?, error: NSError?) in
            guard let document = document else {
                sendError(.notFound, to: response)
                return
            }
            do {
                let retrievedDevice = try ManagedDevice(databaseRecord:document)
                response.send(json: retrievedDevice.responseElement())
            }
            catch let error as EasyLoginError {
                sendError(error, to: response)
            }
            catch {
                sendError(.debug("Internal error"), to: response)
            }
        })
    }
    
    fileprivate func createDeviceHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        guard let parsedBody = request.body else {
            Log.error("body parsing failure")
            sendError(.malformedBody, to:response)
            return
        }
        switch(parsedBody) {
        case .json(let jsonBody):
            do {
                let device = try ManagedDevice(requestElement:jsonBody)
                insert(device, into: database) {
                    createdDevice in
                    guard let createdDevice = createdDevice else {
                        sendError(.debug("Response creation failed"), to: response)
                        return
                    }
                    NotificationService.notifyAllClients()
                    response.statusCode = .created
                    response.headers.setLocation("/db/devices/\(createdDevice.uuid)")
                    response.send(json: createdDevice.responseElement())
                }
            }
            catch let error as EasyLoginError {
                sendError(error, to: response)
            }
            catch {
                sendError(.debug("Device creation failed"), to: response)
            }
        default:
            sendError(.malformedBody, to: response)
        }
    }
    
    fileprivate func listDevicesHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        database.queryByView("all_devices", ofDesign: "main_design", usingParameters: []) { (databaseResponse, error) in
            guard let databaseResponse = databaseResponse else {
                let errorMessage = error?.localizedDescription ?? "error is nil"
                sendError(.debug("Database request failed: \(errorMessage)"), to: response)
                return
            }
            let deviceList = databaseResponse["rows"].array?.flatMap { device -> [String:Any]? in
                if let uuid = device["value"]["uuid"].string,
                    let serialNumber = device["value"]["serialNumber"].string,
                    let deviceName = device["value"]["deviceName"].string {
                    var record = ["uuid":uuid, "serialNumber":serialNumber, "deviceName":deviceName]
                    if let hardwareUUID = device["value"]["hardwareUUID"].string {
                        record["hardwareUUID"] = hardwareUUID
                    }
                    return record
                }
                return nil
            }
            let result = ["devices": deviceList ?? []]
            response.send(json: JSON(result))
        }
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
        do {
            let createdDevice = try ManagedDevice(databaseRecord:document)
            completion(createdDevice)
        }
        catch {
            completion(nil) // TODO: set error
        }
    })
}

