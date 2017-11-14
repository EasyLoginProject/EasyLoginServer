import PackageDescription

let package = Package(
    name: "EasyLogin",
    targets: [
        Target(name: "NotificationService", dependencies: [
            .Target(name: "Extensions")
        ]),
        Target(name: "DirectoryService", dependencies: [
            .Target(name: "Extensions"),
            .Target(name: "NotificationService")
        ]),
        Target(name: "Application", dependencies: [
        	.Target(name: "Extensions"),
        	.Target(name: "DirectoryService"),
        	.Target(name: "NotificationService")
        ]),
        Target(name: "EasyLogin", dependencies: [
            .Target(name: "Application"),
            .Target(name: "Extensions"),
            .Target(name: "DirectoryService"),
            .Target(name: "NotificationService")
        ])
    ],
    dependencies: [
    	.Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 2, minor: 0),
    	.Package(url: "https://github.com/IBM-Swift/Kitura-CouchDB.git", majorVersion: 1, minor: 7),
    	.Package(url: "https://github.com/IBM-Swift/Kitura-WebSocket.git", majorVersion: 0, minor: 9),
    	.Package(url: "https://github.com/IBM-Swift/HeliumLogger.git", majorVersion: 1, minor: 7),
    	.Package(url: "https://github.com/IBM-Swift/CloudConfiguration.git", majorVersion: 2, minor: 0),
        .Package(url: "https://github.com/IBM-Swift/BlueCryptor.git", majorVersion: 0, minor: 8)
    ]
)
