import Foundation
import Kitura

public func sendError(to response: RouterResponse) {
    response.send("This is unexpected.")
}

