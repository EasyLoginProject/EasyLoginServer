//
//  ManagedDevice.swift
//  EasyLoginServer
//
//  Created by Frank on 19/06/17.
//
//

import Foundation
import CouchDB
import SwiftyJSON
import LoggerAPI
import Cryptor

public enum SyncMode: String {
    case strict
    case online
    case auto
    
    init?(optionalRawValue: String?) {
        guard let optionalRawValue = optionalRawValue else { return nil }
        self.init(rawValue: optionalRawValue)
    }
}

// TODO: most fields may be inherited

public struct ManagedDevice: PersistentRecord { // PersistentRecord, Serializable
    enum Key: String {
        case type
        case uuid
        case hardwareUUID
        case serialNumber
        case deviceName
        case tags
        case syncedSets
        case syncSetSelectionMode
        case autoSyncSet
        case mdmProfileSets
        case mdmFeedback
        case mdmPushToken
        case munkiManifests
        case munkiCatalogs
        case munkiApps
        case munkiOptionalApps
        case databaseUUID = "_id"
        case databaseRevision = "_rev"
    }
    
    public fileprivate(set) var revision: String?
    public fileprivate(set) var uuid: String?
    public fileprivate(set) var hardwareUUID: String?
    public fileprivate(set) var serialNumber: String
    public fileprivate(set) var deviceName: String
    public fileprivate(set) var tags: [String]
    public fileprivate(set) var syncedSets: [String]
    public fileprivate(set) var syncSetSelectionMode: SyncMode
    
    // TODO: implement as an enum
    static let type = "device"
    static let deleted = "device_deleted"
}

public enum ManagedDeviceError: Error {
    case notInserted
    case alreadyInserted
    case nullMandatoryField(String)
}

fileprivate extension JSON {
    func mandatoryFieldFromDocument<T>(_ key: ManagedDevice.Key) throws -> T {
        guard let element = self[key.rawValue].object as? T else { throw EasyLoginError.invalidDocument(key.rawValue) }
        return element
    }
    
    func mandatoryFieldFromRequest<T>(_ key: ManagedDevice.Key) throws -> T {
        guard let field = self[key.rawValue].object as? T else { throw EasyLoginError.missingField(key.rawValue) }
        return field
    }
    
    func optionalElement<T>(_ key: ManagedDevice.Key) -> T? {
        return self[key.rawValue].object as? T
    }
    
    func isNull(_ key: ManagedDevice.Key) -> Bool {
        return self[key.rawValue].exists() && Swift.type(of: self[key.rawValue].object) == NSNull.self
    }
}

public extension ManagedDevice { // PersistentRecord
    init(databaseRecord:JSON) throws {
        // No type or unexpected type: requested document was not found
        guard let documentType: String = databaseRecord.optionalElement(.type) else { throw EasyLoginError.notFound }
        guard documentType == ManagedDevice.type else { throw EasyLoginError.notFound }
        // TODO: verify not deleted
        // Missing field: document is invalid
        self.revision = databaseRecord.optionalElement(.databaseRevision)
        self.uuid = try databaseRecord.mandatoryFieldFromDocument(.databaseUUID)
        self.serialNumber = try databaseRecord.mandatoryFieldFromDocument(.serialNumber)
        self.deviceName = try databaseRecord.mandatoryFieldFromDocument(.deviceName)
        self.hardwareUUID = databaseRecord.optionalElement(.hardwareUUID)
        let tags = databaseRecord[Key.tags.rawValue].array
        let syncedSets = databaseRecord[Key.syncedSets.rawValue].array
        let selectionModeName: String = try databaseRecord.mandatoryFieldFromDocument(.syncSetSelectionMode)
        guard let syncSetSelectionMode = SyncMode(rawValue: selectionModeName) else { throw EasyLoginError.invalidDocument(Key.syncSetSelectionMode.rawValue) }
        let filteredTags: [String] = tags?.flatMap { $0.string } ?? []
        self.tags = filteredTags
        let filteredSyncedSets: [String] = syncedSets?.flatMap { $0.string } ?? []
        self.syncedSets = filteredSyncedSets
        self.syncSetSelectionMode = syncSetSelectionMode
    }
    
    func databaseRecord(deleted: Bool = false) throws -> [String:Any] {
        guard let uuid = uuid else { throw ManagedDeviceError.notInserted }
        var record: [String:Any] = [
            Key.databaseUUID.rawValue: uuid,
            Key.type.rawValue: deleted ? ManagedDevice.deleted : ManagedDevice.type,
            Key.serialNumber.rawValue: serialNumber,
            Key.deviceName.rawValue: deviceName,
            Key.tags.rawValue: tags,
            Key.syncedSets.rawValue: syncedSets,
            Key.syncSetSelectionMode.rawValue: syncSetSelectionMode.rawValue
        ]
        if let hardwareUUID = hardwareUUID {
            record[Key.hardwareUUID.rawValue] = hardwareUUID
        }
        return record
    }
}

public extension ManagedDevice { // ServerAPI
    init(requestElement:JSON) throws {
        self.serialNumber = try requestElement.mandatoryFieldFromRequest(.serialNumber)
        self.deviceName = try requestElement.mandatoryFieldFromRequest(.deviceName)
        self.hardwareUUID = requestElement.optionalElement(.hardwareUUID)
        self.tags = requestElement[Key.tags.rawValue].array?.flatMap { $0.string } ?? []
        let uuid = UUID().uuidString
        self.syncedSets = requestElement[Key.syncedSets.rawValue].array?.flatMap { $0.string } ?? [uuid]
        let selectionModeName = requestElement[Key.syncSetSelectionMode.rawValue].string
        self.syncSetSelectionMode = SyncMode(optionalRawValue: selectionModeName) ?? .auto
        self.uuid = uuid
    }
    
    func responseElement() throws -> [String: Any] {
        guard let uuid = uuid else { throw ManagedDeviceError.notInserted }
        var record: [String:Any] = [
            Key.uuid.rawValue: uuid,
            Key.serialNumber.rawValue: serialNumber,
            Key.deviceName.rawValue: deviceName,
            Key.tags.rawValue: tags,
            Key.syncedSets.rawValue: syncedSets,
            Key.syncSetSelectionMode.rawValue: syncSetSelectionMode.rawValue
        ]
        if let hardwareUUID = hardwareUUID {
            record[Key.hardwareUUID.rawValue] = hardwareUUID
        }
        return record
    }
}

public extension ManagedDevice { // mutabiliry
    func inserted() throws -> ManagedDevice {
        if uuid != nil { throw ManagedDeviceError.alreadyInserted }
        var device = self
        device.uuid = UUID().uuidString
        return device
    }
    
    func updated(with requestElement: JSON) throws -> ManagedDevice {
        guard !requestElement.isNull(.serialNumber) else { throw ManagedDeviceError.nullMandatoryField(Key.serialNumber.rawValue) }
        guard !requestElement.isNull(.deviceName) else { throw ManagedDeviceError.nullMandatoryField(Key.deviceName.rawValue) }
        var device = self
        if let hardwareUUID: String = requestElement.optionalElement(.hardwareUUID) {
            device.hardwareUUID = hardwareUUID
        }
        else if requestElement.isNull(.hardwareUUID) {
            device.hardwareUUID = nil
        }
        if let serialNumber: String = requestElement.optionalElement(.serialNumber) {
            device.serialNumber = serialNumber
        }
        if let deviceName: String = requestElement.optionalElement(.deviceName) {
            device.deviceName = deviceName
        }
        // TODO: enforce constraints
        //device.syncedSets = requestElement[Key.syncedSets.rawValue].array?.flatMap { $0.string } ?? [uuid]
        if let selectionModeName: String = requestElement.optionalElement(.syncSetSelectionMode) {
            guard let syncSetSelectionMode = SyncMode(optionalRawValue: selectionModeName) else { throw EasyLoginError.validation(Key.syncSetSelectionMode.rawValue) }
            device.syncSetSelectionMode = syncSetSelectionMode
        }
        return device
    }
}
