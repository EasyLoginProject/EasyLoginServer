import Foundation
import CouchDB
import Configuration
import CloudEnvironment
import CloudFoundryEnv
import LoggerAPI

public extension CouchDBClient {

    public enum Error: Swift.Error {
        case configurationNotAvailable
    }
    
    public convenience init(configurationManager: ConfigurationManager) throws {
        if let dictionary = configurationManager.getManualConfiguration() {
            // When manual database settings have been provided, we use them
            self.init(dictionary: dictionary)
        }
        else if let cloudantService = configurationManager.getCloudantConfiguration() {
            // If no manual config is provided and if we found CloudFoundry based settings, we use them
            self.init(service: cloudantService)
        }
        else {
            throw Error.configurationNotAvailable
        }
    }
    
    public convenience init(service: CloudantCredentials) {
        
        let connProperties = ConnectionProperties(host: service.host,
                                                  port: Int16(service.port),
                                                  secured: true,
                                                  username: service.username,
                                                  password: service.password)
        
        Log.debug("Initializing CouchDBClient with CloudFoundry information: \(connProperties)")
        self.init(connectionProperties: connProperties)
    }
    
    public convenience init(dictionary: [String:Any]) {
        
        let host = dictionary["host"] as? String ?? "127.0.0.1"
        let port = dictionary["port"] as? Int16 ?? 5984
        let username = dictionary["username"] as? String
        let password = dictionary["password"] as? String
        let secured = dictionary["secured"] as? Bool ?? false
        
        let connProperties = ConnectionProperties(host: host,
                                                  port: port,
                                                  secured: secured,
                                                  username: username,
                                                  password: password)
        
        Log.debug("Initializing CouchDBClient with manual/default configuration \(connProperties)")
        self.init(connectionProperties: connProperties)
    }
}
