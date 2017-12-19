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
        .package(url: "https://github.com/IBM-Swift/Kitura.git", from: "2.0.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura-CouchDB.git", from: "1.7.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura-WebSocket.git", from: "0.9.0"),
        .package(url: "https://github.com/IBM-Swift/HeliumLogger.git", from: "1.7.0"),
        .package(url: "https://github.com/IBM-Swift/CloudConfiguration.git", from: "2.0.0"),
        .package(url: "https://github.com/IBM-Swift/BlueCryptor.git", from: "0.8.0"),
    ],
    targets: [
        .target(
            name: "Extensions",
            dependencies: ["CloudConfiguration", "CouchDB", "Cryptor", "Kitura", "Kitura-WebSocket"]),
        .target(
            name: "NotificationService",
            dependencies: ["Extensions"]),
        .target(
            name: "EasyLoginDirectoryService",
            dependencies: ["Extensions", "NotificationService"]),
        .target(
            name: "Application",
            dependencies: ["Extensions", "EasyLoginDirectoryService", "NotificationService"]),
        .target(
            name: "EasyLogin",
            dependencies: ["Application", "Extensions", "EasyLoginDirectoryService", "NotificationService"]),
        .target(
            name: "EasyLoginBootstrap",
            dependencies: ["Application"]),
    ]
)
