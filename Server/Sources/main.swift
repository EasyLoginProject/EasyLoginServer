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

router.get("/whatever/v1/db/users/:uuid") { // can't get uuid with wildcard -- Kitura bug?
	request, response, next in
	defer { next() }
    guard let context = request.userInfo["EasyLoginContext"] as? EasyLoginContext else {
        sendError(to:response)
        return
    }
    guard let uuid = request.parameters["uuid"] else {
        sendError(to:response)
        return
    }
    let database = context.database
    database.retrieve(uuid, callback: { (document: JSON?, error: NSError?) in
        guard let document = document else {
            sendError(to: response)
            return
        }
        guard let retrievedUser = ManagedUser(databaseRecord:document) else {
            sendError(to: response)
            return
        }
        response.send(json: retrievedUser.responseElement())
    })
}

router.post("*/db/users") {
    request, response, next in
    defer { next() }
    Log.debug("handling POST")
    guard let context = request.userInfo["EasyLoginContext"] as? EasyLoginContext else {
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
        database.create(document, callback: { (id: String?, rev: String?, createdDocument: JSON?, error: NSError?) in
            guard let createdDocument = createdDocument else {
                sendError(to: response)
                return
            }
            guard let createdUser = ManagedUser(databaseRecord:document) else {
                sendError(to: response)
                return
            }
            response.send(json: createdUser.responseElement())
        })
    default:
        sendError(to: response)
    }
}

Log.debug("Starting...")
let server = Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

