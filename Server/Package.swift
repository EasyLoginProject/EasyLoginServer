// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EasyLogin",
    products: [
        .executable(
            name: "EasyLogin",
            targets: ["EasyLogin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/Kitura.git", from: "2.0.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura-net.git", .upToNextMinor(from: "1.7.0")),
        .package(url: "https://github.com/IBM-Swift/Kitura-CouchDB.git", from: "1.7.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura-WebSocket.git", from: "0.9.0"),
        .package(url: "https://github.com/IBM-Swift/HeliumLogger.git", from: "1.7.0"),
        .package(url: "https://github.com/IBM-Swift/CloudConfiguration.git", from: "2.0.0"),
        .package(url: "https://github.com/IBM-Swift/BlueCryptor.git", from: "0.8.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura-CORS.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "NotificationService",
            dependencies: ["Extensions"]),
        .target(
            name: "Extensions",
            dependencies: ["CloudConfiguration", "CouchDB", "Cryptor", "Kitura", "Kitura-WebSocket"]),
        .target(
            name: "DataProvider",
            dependencies: ["CloudConfiguration", "CouchDB", "Cryptor", "Kitura", "Extensions"]),
        .target(
            name: "EasyLoginDirectoryService",
            dependencies: ["Extensions", "NotificationService", "DataProvider"]),
        .target(
            name: "EasyLoginLDAPGatewayAPI",
            dependencies: ["Extensions", "NotificationService", "DataProvider"]),
        .target(
            name: "EasyLoginAdminAPI",
            dependencies: ["Extensions", "NotificationService", "DataProvider", "KituraCORS"]),
        .target(
            name: "Application",
            dependencies: ["Extensions", "EasyLoginDirectoryService", "NotificationService", "EasyLoginLDAPGatewayAPI", "EasyLoginAdminAPI"]),
        .target(
            name: "EasyLogin",
            dependencies: ["Application"]),
        .testTarget(
            name: "EasyLoginTests",
            dependencies: ["Extensions", "EasyLoginDirectoryService", "NotificationService", "EasyLoginLDAPGatewayAPI", "EasyLoginAdminAPI", "Application"],
            path: "Tests"),
    ]
)
