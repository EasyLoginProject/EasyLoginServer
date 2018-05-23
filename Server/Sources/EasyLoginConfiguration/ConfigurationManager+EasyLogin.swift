//
//  ConfigurationManager+EasyLogin.swift
//  Extensions
//
//  Created by Frank on 23/01/2018.
//

import Foundation
import Configuration
import CloudEnvironment
import CloudFoundryEnv

public extension ConfigurationManager {
    
    public func getManualConfiguration() -> [String: Any]? {
        return self["database"] as? [String:Any]
    }
    
    public func getCloudantConfiguration() -> CloudantCredentials? {
        return CloudEnv().getCloudantCredentials(name: "EasyLogin-Cloudant")
    }
    
    public func databaseName() -> String {
        return getManualConfiguration()?["name"] as? String ?? "easy_login"
    }
}
