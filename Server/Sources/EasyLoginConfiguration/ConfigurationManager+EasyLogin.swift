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
    
    func getManualConfiguration() -> [String: Any]? {
        return self["database"] as? [String:Any]
    }
    
    func getCloudantConfiguration() -> CloudantCredentials? {
        return CloudEnv().getCloudantCredentials(name: "EasyLogin-Cloudant")
    }
    
    func databaseName() -> String {
        return getManualConfiguration()?["name"] as? String ?? "easy_login"
    }
}
