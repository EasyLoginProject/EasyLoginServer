import Kitura
import LoggerAPI
import HeliumLogger // move to setup

Log.logger = HeliumLogger()

let router = Router()

router.get("/") {
	request, response, next in
	defer { next() }
	response.send("Hello World")
}

let server = Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

