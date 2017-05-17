import Foundation
import Kitura
import LoggerAPI
import HeliumLogger // move to setup
import Application

Log.logger = HeliumLogger()

do {
    try initialize()
    try run()
}
catch let error {
    Log.error(error.localizedDescription)
}
