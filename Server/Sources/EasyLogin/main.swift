import Foundation
import Kitura
import LoggerAPI
import HeliumLogger // move to setup
import Application

HeliumLogger.use(LoggerMessageType.debug)

do {
    try initialize()
    try run()
}
catch let error {
    Log.error(error.localizedDescription)
}
