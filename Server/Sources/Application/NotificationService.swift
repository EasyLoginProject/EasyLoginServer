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

private var service: NotificationService?

public func installNotificationService() {
    service = NotificationService()
    WebSocket.register(service: service!, onPath: "notifications")
}

public let directoryDidChangeNotificationName = NSNotification.Name(rawValue: "EasyLoginDirectoryDidChange")

class NotificationService {
    var connections: [String: WebSocketConnection]
    let notificationQueue = OperationQueue()
    
    init() {
        connections = [String: WebSocketConnection]()
        NotificationCenter.default.addObserver(forName: directoryDidChangeNotificationName, object: nil, queue: notificationQueue, using: self.didReceiveChangeNotification)
    }
}

extension NotificationService: WebSocketService {
    public func connected(connection: WebSocketConnection) {
        connections[connection.id] = connection
    }
    
    public func disconnected(connection: WebSocketConnection, reason: WebSocketCloseReasonCode) {
        connections.removeValue(forKey: connection.id)
    }
    
    public func received(message: Data, from: WebSocketConnection) {
        // ignore
    }
    
    public func received(message: String, from: WebSocketConnection) {
        // ignore
    }
}

extension NotificationService {
    func didReceiveChangeNotification(notification: Notification) {
        Log.info("Send 'update' message to all websocket connections")
        connections.forEach { (_, connection) in
            Log.info("--> update")
            connection.send(message: "update")
        }
    }
}
