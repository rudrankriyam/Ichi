// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "IchiConversation",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(name: "IchiConversation", targets: ["IchiConversation"])
  ],
  targets: [
    .target(
      name: "IchiConversation",
      path: "Ichi",
      exclude: [
        "Assets.xcassets",
        "AVSpeechTTSProvider.swift",
        "ConversationConformances.swift",
        "Ichi.entitlements",
        "IchiApp.swift",
        "KokoroTTSProvider.swift",
        "MainView.swift",
        "OnDeviceProcessor.swift",
        "OnboardingView.swift",
        "SettingsView.swift",
        "SpeechRecognizer.swift",
        "TTSManager.swift",
        "TTSProtocol.swift",
        "Views",
      ],
      sources: [
        "AppState.swift",
        "ConversationInterfaces.swift",
        "SpeechRecognitionRequestFactory.swift",
        "VoiceConversationController.swift",
      ]
    ),
    .testTarget(
      name: "IchiConversationTests",
      dependencies: ["IchiConversation"],
      path: "IchiConversationTests"
    ),
  ]
)
