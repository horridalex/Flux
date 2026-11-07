// swift-tools-version:5.9
// Only for `swift test` on the Mac. The app itself builds from project.yml. FluxWG is the
// WireGuard server in Go: run scripts/build-wireguard.sh first (xcodegen runs it too).
import PackageDescription

let package = Package(
    name: "Flux",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        .target(name: "FluxCore", dependencies: ["FluxWG"], path: "Sources", sources: ["Traffic.swift", "WireGuardSetup.swift", "WireGuardServer.swift", "AppExpiry.swift", "KeepAlivePolicy.swift", "Format.swift", "ShortcutReply.swift", "Usage.swift"]),
        .binaryTarget(name: "FluxWG", path: "WireGuard/build/FluxWG.xcframework"),
        .testTarget(name: "FluxTests", dependencies: ["FluxCore"], path: "Tests"),
    ]
)
