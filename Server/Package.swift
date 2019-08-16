// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EasyLogin",
    products: [
        .executable(
            name: "EasyLogin",
            targets: ["EasyLogin"]),
        .executable(
            name: "EasyLoginBootstrap",
            targets: ["EasyLoginBootstrap"]),
    ],
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/Kitura.git", from: "2.3.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura-net.git", from: "2.1.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura-CouchDB.git", from: "2.1.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura-WebSocket.git", from: "2.0.0"),
        .package(url: "https://github.com/IBM-Swift/HeliumLogger.git", from: "1.7.0"),
        .package(url: "https://github.com/IBM-Swift/CloudEnvironment.git", .upToNextMajor(from: "6.0.0")),
        .package(url: "https://github.com/IBM-Swift/BlueCryptor.git", from: "1.0.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura-CORS.git", from: "2.1.0"),
        .package(url: "https://github.com/RuntimeTools/SwiftMetrics.git", from: "2.3.0")
    ],
    targets: [
        .target(
            name: "NotificationService",
            dependencies: ["Extensions"]),
        .target(
            name: "Extensions",
            dependencies: ["CouchDB", "Cryptor", "Kitura", "Kitura-WebSocket", "KituraNet"]),
        .target(
            name: "DataProvider",
            dependencies: ["CouchDB", "Cryptor", "Kitura", "Extensions", "NotificationService"]),
        .target(
            name: "EasyLoginConfiguration",
            dependencies: ["CloudEnvironment", "CouchDB"]),
        .target(
            name: "EasyLoginDirectoryService",
            dependencies: ["EasyLoginConfiguration", "Extensions", "NotificationService", "DataProvider"]),
        .target(
            name: "EasyLoginLDAPGatewayAPI",
            dependencies: ["Extensions", "NotificationService", "DataProvider"]),
        .target(
            name: "EasyLoginAdminAPI",
            dependencies: ["Extensions", "NotificationService", "DataProvider", "KituraCORS"]),
        .target(
            name: "Application",
            dependencies: ["EasyLoginConfiguration", "Extensions", "EasyLoginDirectoryService", "NotificationService", "EasyLoginLDAPGatewayAPI", "EasyLoginAdminAPI", "SwiftMetrics", "HeliumLogger"]),
        .target(
            name: "EasyLogin",
            dependencies: ["Application"]),
        .target(
            name: "EasyLoginBootstrap",
            dependencies: ["Application"]),
        .testTarget(
            name: "EasyLoginTests",
            dependencies: ["Extensions", "EasyLoginDirectoryService", "NotificationService", "EasyLoginLDAPGatewayAPI", "EasyLoginAdminAPI", "Application"],
            path: "Tests"),
    ]
)
