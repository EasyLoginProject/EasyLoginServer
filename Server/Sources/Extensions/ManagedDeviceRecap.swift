//
//  ManagedDeviceRecap.swift
//  Extensions
//
//  Created by Frank on 26/11/2017.
//

import Foundation
import SwiftyJSON

public struct ManagedDeviceRecap: PersistentRecord, Encodable {
    enum Key: String {
        case uuid
        case hardwareUUID
        case serialNumber
        case deviceName
    }
    
    public fileprivate(set) var uuid: String?
    public fileprivate(set) var hardwareUUID: String?
    public fileprivate(set) var serialNumber: String
    public fileprivate(set) var deviceName: String
}

fileprivate extension JSON {
    func mandatoryFieldFromDocument<T>(_ key: ManagedDeviceRecap.Key) throws -> T {
        guard let element = self[key.rawValue].object as? T else { throw EasyLoginError.invalidDocument(key.rawValue) }
        return element
    }
    
    func optionalElement<T>(_ key: ManagedDeviceRecap.Key) -> T? {
        return self[key.rawValue].object as? T
    }
}

public extension ManagedDeviceRecap { // PersistentRecord
    init(databaseRecord:JSON) throws {
        self.uuid = try databaseRecord.mandatoryFieldFromDocument(.uuid)
        self.serialNumber = try databaseRecord.mandatoryFieldFromDocument(.serialNumber)
        self.deviceName = try databaseRecord.mandatoryFieldFromDocument(.deviceName)
        self.hardwareUUID = databaseRecord.optionalElement(.hardwareUUID)
    }
}
