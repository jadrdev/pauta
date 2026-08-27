// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pauta",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        // Modelos y persistencia, sin nada de UI: lo usa la app de macOS hoy
        // y lo compartirán el widget y la app de iOS el día que existan.
        .target(
            name: "PautaCore",
            path: "Sources/PautaCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Pauta",
            dependencies: ["PautaCore"],
            path: "Sources/Pauta",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
