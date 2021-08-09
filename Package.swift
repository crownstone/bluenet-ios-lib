// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let package = Package(
    name: "BluenetLib",
    platforms: [
        .iOS(.v10),
        .watchOS(.v4),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BluenetLib",
            targets: ["BluenetLib"]
        )
    ],
    dependencies: [
        .package(
            name:"BluenetShared",
            url: "https://github.com/crownstone/bluenet-ios-shared",
            .exact("2.0.0")
        ),
        .package(
            url: "https://github.com/krzyzanowskim/CryptoSwift",
            .exact("1.3.8")
        ),
        .package(
            url: "https://github.com/SwiftyJSON/SwiftyJSON",
            .exact("5.0.0")
        ),
        .package(
            name:"NordicDFU",
            url: "https://github.com/NordicSemiconductor/IOS-Pods-DFU-Library",
            .exact("4.9.0")
        ),
        .package(
            url: "https://github.com/mxcl/PromiseKit",
            .exact("6.13.2")
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "BluenetLib",
            dependencies: ["PromiseKit","CryptoSwift","BluenetShared","NordicDFU","SwiftyJSON"],
            path: "Sources"
        ),
        .testTarget(
            name: "BluenetLibTests",
            dependencies: ["PromiseKit","CryptoSwift","BluenetShared","NordicDFU","SwiftyJSON", "BluenetLib"]),
    ]
)

if ProcessInfo.processInfo.environment["TARGETING_WATCHOS"] == "true" {
  // #workaround(xcodebuild -version 11.6, Test targets don’t work on watchOS.) @exempt(from: unicode)
  package.targets.removeAll(where: { $0.isTest })
}
