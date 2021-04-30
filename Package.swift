// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "SyncKit",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v11),
        .tvOS(.v11),
        .watchOS(.v3)
    ],
    products: [
        .library(name: "SyncKit/CoreData", targets: ["SyncKit/CoreData"]),
        .library(name: "SyncKit/Realm", targets: ["SyncKit/Realm"]),
        .library(name: "SyncKit/RealmSwift", targets: ["SyncKit/RealmSwift"])],
    dependencies: [
        .package(url: "https://github.com/realm/realm-cocoa", from: "10.5.2")
    ],
    targets: [
        .target(
            name: "SyncKit/CoreData",
            dependencies: [],
            path: ".",
            sources: ["SyncKit/Classes/CoreData"]
        ),
         .target(
            name: "SyncKit/Realm",
            dependencies: ["Realm"],
            path: ".",
            sources: ["SyncKit/Classes/Realm"]
        ),
        .target(
            name: "SyncKit/RealmSwift",
            dependencies: ["RealmSwift", "Realm"],
            path: ".",
            sources: ["SyncKit/Classes/RealmSwift"]
        )
    ],
    swiftLanguageVersions: [.v5]
)