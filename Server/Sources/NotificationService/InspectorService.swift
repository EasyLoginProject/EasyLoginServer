//
//  DebugService.swift
//  EasyLogin
//
//  Created by Frank on 28/06/17.
//
//

import Foundation
import Kitura
import Extensions

public class InspectorService {
    private var inspectableServices: [String: Inspectable]
    
    public init() {
        inspectableServices = [:]
    }
    
    public func registerInspectable(_ inspectable: Inspectable, name: String) -> Void {
        inspectableServices[name] = inspectable
    }
    
    public func installHandlers(to router: Router) {
        router.get("inspect", handler: inspectHandler)
    }
    
    fileprivate func inspectHandler(request: RouterRequest, response: RouterResponse, next: ()->Void) -> Void {
        defer { next() }
        var result: [String: [String: Any]] = [:]
        inspectableServices.forEach { (serviceName, inspectedService) in
            result[serviceName] = inspectedService.inspect()
        }
        response.send(json: result)
    }
}
