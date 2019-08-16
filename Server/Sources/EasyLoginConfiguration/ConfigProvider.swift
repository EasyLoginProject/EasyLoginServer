//
//  ConfigProvider.swift
//  DataProvider
//
//  Created by Yoann Gini on 01/01/2018.
//

import Foundation
import Configuration

public class ConfigProvider {
    public static let pathForResources: String = {
        let resourcePath: String
        if let environmentVariable = getenv("RESOURCES"), let envResourcePath = String(validatingUTF8: environmentVariable) {
            resourcePath = envResourcePath
        }
        else {
            resourcePath = "Resources"
        }
        return resourcePath
    }()
    
    public static let manager: ConfigurationManager = {
        let manager = ConfigurationManager()
        
        manager.load(.commandLineArguments)
        if let configFile = manager["config"] as? String {
            manager.load(file:configFile)
        }
        manager.load(.environmentVariables)
            .load(.commandLineArguments) // always give precedence to CLI args
        
        return manager
    }()
    
    private init() {
        
    }
    
    public static func pathForResource(_ resourceSubPath: String) -> String {
        return "\(pathForResources)/\(resourceSubPath)"
    }
}
