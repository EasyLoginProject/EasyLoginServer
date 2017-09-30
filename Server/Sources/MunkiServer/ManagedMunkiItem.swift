//
//  ManagedMunkiItem.swift
//  EasyLogin
//
//  Created by Yoann Gini on 29/09/2017.
//
//

import Foundation
import CouchDB
import Kitura
import DataProvider
import SwiftyJSON
import Extensions

public class ManagedMunkiItem : DataProvider.ManagedObject {
    override public class var objectType : String {return "munki_item"}
    
    enum ManagedMunkiItemKey : String {
        case name
        case display_name
    }
    
    public fileprivate(set) var name: String?
    public fileprivate(set) var display_name: String?
    
    required public init(databaseRecord:JSON) throws {
        try super.init(databaseRecord: databaseRecord)
        
        self.name = try databaseRecord.mandatoryFieldFromDocument(ManagedMunkiItemKey.name.rawValue)
        self.display_name = try databaseRecord.mandatoryFieldFromDocument(ManagedMunkiItemKey.display_name.rawValue)
    }
    
    override open func dictionaryRepresentation() throws -> [String:Any] {
        var record = try super.dictionaryRepresentation()
        
        if let name = name {
            record[ManagedMunkiItemKey.name.rawValue] = name
        }
        
        return record
    }
}
