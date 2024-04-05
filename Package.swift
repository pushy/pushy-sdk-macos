// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PushyMacOS",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .library(
      name: "PushyMacOS",
      targets: ["PushyMacOS"]
    )
  ],
  dependencies: [
      .package(url: "https://github.com/emqx/CocoaMQTT", from: "2.1.0"),
  ],
  targets: [
    .target(
      name: "PushyMacOS",
      dependencies: ["CocoaMQTT"],
      path: "PushySDK"
    )
  ]
)
