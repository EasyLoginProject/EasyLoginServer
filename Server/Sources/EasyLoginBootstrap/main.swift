import Foundation
import Kitura
import LoggerAPI
import HeliumLogger // move to setup
import Application

HeliumLogger.use(LoggerMessageType.debug)

print("Bootstrap")

do {
    try bootstrap()
}
catch {
    print("error: \(error)")
}
