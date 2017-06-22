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

private var service: NotificationService?

public func installNotificationService() {
    service = NotificationService()
    WebSocket.register(service: service!, onPath: "notifications")
}

public let directoryDidChangeNotificationName = NSNotification.Name(rawValue: "EasyLoginDirectoryDidChange")

class NotificationService {
    var connections: [String: WebSocketConnection]
    let connectionsMutex = DispatchSemaphore(value: 1)
    let notificationQueue = OperationQueue()
    
    init() {
        connections = [String: WebSocketConnection]()
#if os(Linux)
        NotificationCenter.default.addObserver(forName: directoryDidChangeNotificationName, object: nil, queue: notificationQueue, usingBlock: self.didReceiveChangeNotification)
#else
        NotificationCenter.default.addObserver(forName: directoryDidChangeNotificationName, object: nil, queue: notificationQueue, using: self.didReceiveChangeNotification)
#endif
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
    func didReceiveChangeNotification(notification: Notification) {
        Log.info("Send 'update' message to all websocket connections")
        lockConnections()
        connections.forEach { (_, connection) in
            Log.info("--> update")
            connection.send(message: "update")
        }
        unlockConnections()
    }
}
