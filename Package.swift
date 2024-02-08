// swift-tools-version: 5.9

import CompilerPluginSupport
import Foundation
import PackageDescription

var package = Package(
  name: "swift-mmio",
  platforms: [
    .macOS(.v14),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .macCatalyst(.v13),
    .visionOS(.v1),
  ],
  products: [
    // MMIO
    .library(name: "MMIO", targets: ["MMIO"]),

    // SVD
    .executable(
      // FIXME: rdar://112530586
      // XPM skips build plugin if product and target names are not identical.
      // Rename this target to "SVD2Swift" when Xcode bug is resolved.
      name: "SVD2Swift",
      targets: ["SVD2Swift"]),
    .plugin(name: "SVD2SwiftPlugin", targets: ["SVD2SwiftPlugin"]),
    .library(name: "SVD", targets: ["SVD"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.2"),
  ],
  targets: [
    // MMIO
    .target(
      name: "MMIO",
      dependencies: ["MMIOMacros", "MMIOVolatile"]),
    .testTarget(
      name: "MMIOFileCheckTests",
      dependencies: ["MMIOUtilities"],
      exclude: ["Tests"]),
    .testTarget(
      name: "MMIOInterposableTests",
      dependencies: ["MMIO", "MMIOUtilities"]),
    .testTarget(
      name: "MMIOTests",
      dependencies: ["MMIO", "MMIOUtilities"]),

    .macro(
      name: "MMIOMacros",
      dependencies: [
        "MMIOUtilities",
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftOperators", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      ]),
    .testTarget(
      name: "MMIOMacrosTests",
      dependencies: [
        "MMIOMacros",
        // FIXME: rdar://119344431
        // XPM drops transitive dependency causing linker errors.
        // Remove this dependency when Xcode bug is resolved.
        "MMIOUtilities",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]),

    .target(name: "MMIOUtilities"),
    .testTarget(
      name: "MMIOUtilitiesTests",
      dependencies: ["MMIOUtilities"]),

    .systemLibrary(name: "MMIOVolatile"),

    // SVD
    .target(
      name: "SVD",
      dependencies: ["MMIOUtilities", "SVDMacros"]),

    .executableTarget(
      name: "SVD2Swift",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "SVD",
      ]),
    .testTarget(
      name: "SVD2SwiftTests",
      dependencies: ["MMIO"],
      // FIXME: rdar://113256834,apple/swift-package-manager#6935
      // SPM 5.9 produces warnings for plugin input files.
      // Remove this exclude list when Swift Package Manager bug is resolved.
      exclude: ["ARM_Sample.svd", "svd2swift.json"],
      plugins: ["SVD2SwiftPlugin"]),

    .plugin(
      name: "SVD2SwiftPlugin",
      capability: .buildTool,
      dependencies: ["SVD2Swift"]),

    .macro(
      name: "SVDMacros",
      dependencies: [
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      ]),
    .testTarget(
      name: "SVDMacrosTests",
      dependencies: [
        "SVDMacros",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]),
  ])


// Replace these with a native SPM feature flags if/when supported.
let svd2lldb = "FEATURE_SVD2LLDB"
if featureIsEnabled(named: svd2lldb, override: true) {
  let frameworks = """
    /Library/Developer/Toolchains/\
    swift-DEVELOPMENT-SNAPSHOT-2024-01-08-a.xctoolchain\
    /System/Library/PrivateFrameworks
    """


  package.targets.append(
    .target(
      name: "CLLDB",
      cSettings: [
        .unsafeFlags([
          "-I\(frameworks)/LLDB.framework/Headers",
          "-I\(frameworks)/LLDB.framework",
          "-F\(frameworks)",
        ])
      ]))

  package.targets.append(
    .target(
      name: "SVD2LLDB",
      dependencies: ["CLLDB", "SVD"],
      swiftSettings: [
        .interoperabilityMode(.Cxx),
        .unsafeFlags([
          "-I\(frameworks)/LLDB.framework/Headers",
          "-I\(frameworks)/LLDB.framework",
          "-F\(frameworks)",
          "-framework", "LLDB",
        ])
      ],
      linkerSettings: [
        .unsafeFlags(["-F\(frameworks)"]),
        .linkedFramework("LLDB")
      ]
    ))


  package.products.append(
    .library(
      name: "SVD2LLDB",
      type: .dynamic,
      targets: ["SVD2LLDB"]))
}

let interposable = "FEATURE_INTERPOSABLE"
if featureIsEnabled(named: interposable, override: nil) {
  let allowedTargets = Set([
    "MMIO", "MMIOVolatile", "MMIOMacros", "MMIOUtilities",
    "MMIOInterposableTests",
  ])
  package.targets = package.targets.filter {
    allowedTargets.contains($0.name)
  }
  for target in package.targets where target.type != .system {
    target.swiftDefine(interposable)
  }
} else {
  let disallowedTargets = Set(["MMIOInterposableTests"])
  package.targets = package.targets.filter {
    !disallowedTargets.contains($0.name)
  }
}

// Package API Extensions
func featureIsEnabled(named featureName: String, override: Bool?) -> Bool {
  let key = "SWIFT_MMIO_\(featureName)"
  let environment = ProcessInfo.processInfo.environment[key] != nil
  return override ?? environment
}

extension Target {
  func swiftDefine(_ value: String) {
    var swiftSettings = self.swiftSettings ?? []
    swiftSettings.append(.define(value))
    self.swiftSettings = swiftSettings
  }
}
