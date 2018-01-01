//
//  ConfigProvider.swift
//  DataProvider
//
//  Created by Yoann Gini on 01/01/2018.
//

import Foundation
import Configuration
import CloudFoundryConfig

public class ConfigProvider {
    public static let pathForResources: String = {
        let ressourcePath: String
        if let environmentVariable = getenv("RESOURCES"), let envResourcePath = String(validatingUTF8: environmentVariable) {
            ressourcePath = envResourcePath
        }
        else {
            ressourcePath = "Resources"
        }
        return ressourcePath
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
    
    public static func pathForRessource(_ ressourceSubPath: String) -> String {
        return "\(pathForResources)/\(ressourceSubPath)"
    }
}
