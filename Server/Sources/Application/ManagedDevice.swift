//
//  ManagedDevice.swift
//  EasyLogin
//
//  Created by Frank on 20/06/17.
//
//

import Foundation
import CouchDB
import SwiftyJSON
import LoggerAPI
import Cryptor

enum CDSSyncMode: String {
    case strict
    case online
    case auto
    
    init?(optionalRawValue: String?) {
        guard let optionalRawValue = optionalRawValue else { return nil }
        self.init(rawValue: optionalRawValue)
    }
}

// TODO: most fields may be inherited

struct ManagedDevice { // PersistentRecord, Serializable
    enum Key: String {
        case type
        case uuid
        case hardwareUUID
        case serialNumber
        case deviceName
        case lockedTime
        case tags
        case cdsSyncedSets
        case cdsSelectionMode
        case cdsAutoSyncSet
        case mdmProfileSets
        case mdmFeedback
        case mdmPushToken
        case munkiManifests
        case munkiCatalogs
        case munkiApps
        case munkiOptionalApps
    }
    
    let uuid: String
    let hardwareUUID: String?
    let serialNumber: String
    let deviceName: String
    let tags: [String]
    let cdsSyncedSets: [String]
    let cdsSelectionMode: CDSSyncMode
    
    let type = "device"
}

extension ManagedDevice { // PersistentRecord
    init?(databaseRecord:JSON) {
        guard let uuid = databaseRecord["_id"].string else { return nil }
        guard let serialNumber = databaseRecord[Key.serialNumber.rawValue].string else { return nil }
        guard let deviceName = databaseRecord[Key.deviceName.rawValue].string else { return nil }
        let hardwareUUID = databaseRecord[Key.hardwareUUID.rawValue].string
        let tags = databaseRecord[Key.tags.rawValue].array
        let cdsSyncedSets = databaseRecord[Key.cdsSyncedSets.rawValue].array
        guard let cdsSelectionModeName = databaseRecord[Key.cdsSelectionMode.rawValue].string else { return nil }
        guard let cdsSelectionMode = CDSSyncMode(rawValue: cdsSelectionModeName) else { return nil }
        self.uuid = uuid
        self.serialNumber = serialNumber
        self.deviceName = deviceName
        self.hardwareUUID = hardwareUUID
        let filteredTags: [String] = tags?.flatMap { $0.string } ?? []
        self.tags = filteredTags
        let filteredSyncedSets: [String] = cdsSyncedSets?.flatMap { $0.string } ?? []
        self.cdsSyncedSets = filteredSyncedSets
        self.cdsSelectionMode = cdsSelectionMode
    }
    
    func databaseRecord() -> [String:Any] {
        var record: [String:Any] = [
            "_id": uuid,
            Key.type.rawValue: type,
            Key.serialNumber.rawValue: serialNumber,
            Key.deviceName.rawValue: deviceName,
            Key.tags.rawValue: tags,
            Key.cdsSyncedSets.rawValue: cdsSyncedSets,
            Key.cdsSelectionMode.rawValue: cdsSelectionMode.rawValue
        ]
        if let hardwareUUID = hardwareUUID {
            record[Key.hardwareUUID.rawValue] = hardwareUUID
        }
        return record
    }
}

extension ManagedDevice { // ServerAPI
    init?(requestElement:JSON) {
        guard let serialNumber = requestElement[Key.serialNumber.rawValue].string else { return nil }
        guard let deviceName = requestElement[Key.deviceName.rawValue].string else { return nil }
        let uuid = UUID().uuidString
        let hardwareUUID = requestElement[Key.hardwareUUID.rawValue].string
        let tags = requestElement[Key.tags.rawValue].array?.flatMap { $0.string } ?? []
        let cdsSyncedSets = requestElement[Key.cdsSyncedSets.rawValue].array?.flatMap { $0.string } ?? [uuid]
        let cdsSelectionModeName = requestElement[Key.cdsSelectionMode.rawValue].string
        let cdsSelectionMode = CDSSyncMode(optionalRawValue: cdsSelectionModeName) ?? .auto
        self.uuid = uuid
        self.serialNumber = serialNumber
        self.deviceName = deviceName
        self.hardwareUUID = hardwareUUID
        self.tags = tags
        self.cdsSyncedSets = cdsSyncedSets
        self.cdsSelectionMode = cdsSelectionMode
    }
    
    func responseElement() -> JSON {
        var record: [String:Any] = [
            Key.uuid.rawValue: uuid,
            Key.serialNumber.rawValue: serialNumber,
            Key.deviceName.rawValue: deviceName,
            Key.tags.rawValue: tags,
            Key.cdsSyncedSets.rawValue: cdsSyncedSets,
            Key.cdsSelectionMode.rawValue: cdsSelectionMode.rawValue
        ]
        if let hardwareUUID = hardwareUUID {
            record[Key.hardwareUUID.rawValue] = hardwareUUID
        }
        return JSON(record)
    }
}

