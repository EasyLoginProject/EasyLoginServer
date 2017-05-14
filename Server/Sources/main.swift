import Foundation
import Kitura
import LoggerAPI
import HeliumLogger // move to setup
import SwiftyJSON

func sendError(to response: RouterResponse) {
    response.send("This is unexpected.")
}

Log.logger = HeliumLogger()

let dbRegistry = DatabaseRegistry()
//dbRegistry.createDatabase(name: "ground_control")

let router = Router()
router.all(middleware:ContextLoader(databaseRegistry: dbRegistry))
router.post(middleware:BodyParser())
router.put(middleware:BodyParser())

router.get("*/db/users/:id") {
	request, response, next in
	defer { next() }
    if let context = request.userInfo["GroundControlContext"] as? DirectoryContext {
        let database = context.database
        // send query to database here...
        response.send("Connected to database.")
    }
    else {
        response.send("This is unexpected.")
    }
}

router.post("*/db/users") {
    request, response, next in
    defer { next() }
    Log.debug("handling POST")
    guard let context = request.userInfo["GroundControlContext"] as? DirectoryContext else {
        Log.error("no context")
        sendError(to:response)
        return
    }
    guard let parsedBody = request.body else {
        Log.error("body parsing failure")
        sendError(to:response)
        return
    }
    Log.debug("handling body")
    switch(parsedBody) {
    case .json(let jsonBody):
        guard let user = ManagedUser(requestElement:jsonBody) else {
            sendError(to: response)
            return
        }
        let database = context.database
        let document = JSON(user.databaseRecord())
        database.create(document, callback: { (id: String?, rev: String?, document: JSON?, error: NSError?) in
            if let error = error {
                response.send("Error: \(error)")
            } else {
                response.send(json: user.responseElement())
            }
        })
    default:
        sendError(to: response)
    }
}

Log.debug("Starting...")
let server = Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

