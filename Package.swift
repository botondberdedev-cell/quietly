// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuietlyCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "QuietlyCore", targets: ["QuietlyCore"])],
    targets: [
        .target(name: "QuietlyCore", path: "Quietly/Core"),
        .testTarget(name: "QuietlyCoreTests", dependencies: ["QuietlyCore"], path: "Tests/Core")
    ]
)
