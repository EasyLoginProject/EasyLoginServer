//
//  ConfigurationManager+EasyLogin.swift
//  Extensions
//
//  Created by Frank on 23/01/2018.
//

import Foundation
import Configuration
import CloudFoundryConfig

public extension ConfigurationManager {
    
    public func getManualConfiguration() -> [String: Any]? {
        return self["database"] as? [String:Any]
    }
    
    public func getCloudantConfiguration() -> CloudantService? {
        return try? self.getCloudantService(name: "EasyLogin-Cloudant")
    }
    
    public func databaseName() -> String {
        return getManualConfiguration()?["name"] as? String ?? "easy_login"
    }
}
