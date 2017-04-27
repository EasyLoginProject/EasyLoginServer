import Kitura
import LoggerAPI
import HeliumLogger // move to setup

Log.logger = HeliumLogger()

let dbRegistry = DatabaseRegistry()
dbRegistry.createDatabase(name: "ground_control")

let router = Router()

router.get("/") {
	request, response, next in
	defer { next() }
	let database = dbRegistry.database()
	response.send("Hello World")
}

let server = Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

