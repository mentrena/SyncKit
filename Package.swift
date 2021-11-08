// swift-tools-version:5.3
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
            path: "SyncKit/Classes/CoreData",
            resources: [
                .process("QSCloudKitSyncModel.xcdatamodeld")
            ],
            swiftSettings: [
                .define("SPM")
            ]
        ),
         .target(
            name: "SyncKit/Realm",
            dependencies: [
                .product(name: "Realm", package: "realm-cocoa")
            ],
            path: "SyncKit/Classes/Realm"
        ),
        .target(
            name: "SyncKit/RealmSwift",
            dependencies: [
                .product(name: "RealmSwift", package: "realm-cocoa"),
                .product(name: "Realm", package: "realm-cocoa")
            ],
            path: "SyncKit/Classes/RealmSwift"
        )
    ],
    swiftLanguageVersions: [.v5]
)
