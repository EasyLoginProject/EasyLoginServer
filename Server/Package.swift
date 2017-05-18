import PackageDescription

let package = Package(
    name: "EasyLogin",
    targets: [
        Target(name: "EasyLogin", dependencies: [ .Target(name: "Application") ])
    ],
    dependencies: [
    	.Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1, minor: 7),
    	.Package(url: "https://github.com/IBM-Swift/Kitura-CouchDB.git", majorVersion: 1, minor: 7),
    	.Package(url: "https://github.com/IBM-Swift/Kitura-WebSocket.git", majorVersion: 0, minor: 8),
    	.Package(url: "https://github.com/IBM-Swift/HeliumLogger.git", majorVersion: 1, minor: 7),
    	.Package(url: "https://github.com/IBM-Swift/CloudConfiguration.git", majorVersion: 2)
    ]
)
