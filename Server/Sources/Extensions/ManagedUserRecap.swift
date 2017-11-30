//
//  ManagedUserRecap.swift
//  Extensions
//
//  Created by Frank on 26/11/2017.
//

import Foundation
import SwiftyJSON

public struct ManagedUserRecap: PersistentRecord, Encodable {
    enum Key: String {
        case uuid
        case numericID
        case shortname
    }
    
    public fileprivate(set) var uuid: String?
    public fileprivate(set) var numericID: Int?
    public fileprivate(set) var shortName: String
}

fileprivate extension JSON {
    func mandatoryElement<T>(_ key: ManagedUserRecap.Key) throws -> T {
        guard let element = self[key.rawValue].object as? T else { throw EasyLoginError.invalidDocument(key.rawValue) }
        return element
    }
}

public extension ManagedUserRecap { // PersistentRecord
    init(databaseRecord:JSON) throws {
        self.uuid = try databaseRecord.mandatoryElement(.uuid)
        //self.numericID = try databaseRecord.mandatoryElement(.numericID)
        guard let numericID = databaseRecord[Key.numericID.rawValue].int else { throw EasyLoginError.invalidDocument(Key.numericID.rawValue) }
        self.numericID = numericID
        self.shortName = try databaseRecord.mandatoryElement(.shortname)
    }
}
