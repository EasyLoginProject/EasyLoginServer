//
//  NotificationService.swift
//  EasyLogin
//
//  Created by Frank on 21/06/17.
//
//

import Foundation
import Kitura
import KituraWebSocket
import LoggerAPI
import Dispatch
import Extensions

private var service: NotificationService?

public func installNotificationService() -> NotificationService {
    service = NotificationService()
    WebSocket.register(service: service!, onPath: "notifications")
    return service!
}

public class NotificationService {
    var connections: [String: WebSocketConnection]
    let connectionsMutex = DispatchSemaphore(value: 1)
    
    init() {
        connections = [String: WebSocketConnection]()
    }
    
    func lockConnections() {
        _ = connectionsMutex.wait(timeout: DispatchTime.distantFuture)
    }
    
    func unlockConnections() {
        connectionsMutex.signal()
    }
}

extension NotificationService: WebSocketService {
    public func connected(connection: WebSocketConnection) {
        lockConnections()
        connections[connection.id] = connection
        unlockConnections()
    }
    
    public func disconnected(connection: WebSocketConnection, reason: WebSocketCloseReasonCode) {
        lockConnections()
        connections.removeValue(forKey: connection.id)
        unlockConnections()
    }
    
    public func received(message: Data, from: WebSocketConnection) {
        // ignore
    }
    
    public func received(message: String, from: WebSocketConnection) {
        // ignore
    }
}

extension NotificationService {
    func sendUpdateMessage() {
        Log.info("Send 'update' message to all websocket connections")
        lockConnections()
        connections.forEach { (_, connection) in
            Log.info("--> update")
            connection.send(message: "update")
        }
        unlockConnections()
    }
    
    public static func notifyAllClients() { // temporary, to be replaced with NotificationCenter when available
        service?.sendUpdateMessage()
    }
}

extension NotificationService: Inspectable {
    public func inspect() -> [String : Any] {
        return ["connections": connections.count]
    }
}
