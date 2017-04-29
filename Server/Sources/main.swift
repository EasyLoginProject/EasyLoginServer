import Kitura
import LoggerAPI
import HeliumLogger // move to setup

Log.logger = HeliumLogger()

let dbRegistry = DatabaseRegistry()
//dbRegistry.createDatabase(name: "ground_control")

let router = Router()
router.all(middleware:ContextLoader(databaseRegistry: dbRegistry))

router.get("*/db/users/*") {
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

let server = Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

