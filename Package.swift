// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Pushy",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .library(
      name: "Pushy",
      targets: ["Pushy"]
    )
  ],
  dependencies: [
      .package(url: "https://github.com/emqx/CocoaMQTT", from: "2.1.0"),
  ],
  targets: [
    .target(
      name: "Pushy",
      dependencies: ["CocoaMQTT"],
      path: "PushySDK"
    )
  ]
)
