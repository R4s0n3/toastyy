// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToastyyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ToastyyCore", targets: ["ToastyyCore"])],
    targets: [
        .target(name: "ToastyyCore"),
        .testTarget(name: "ToastyyCoreTests", dependencies: ["ToastyyCore"]),
    ]
)
