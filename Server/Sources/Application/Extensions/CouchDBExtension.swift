import Foundation
import CouchDB
import CloudFoundryConfig

extension CouchDBClient {

    public convenience init(service: CloudantService) {
        
        let connProperties = ConnectionProperties(host: service.host,
                                                  port: Int16(service.port),
                                                  secured: true,
                                                  username: service.username,
                                                  password: service.password)
        
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
        
        self.init(connectionProperties: connProperties)
    }
    
}
