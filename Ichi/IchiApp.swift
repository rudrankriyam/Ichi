//
//  IchiApp.swift
//  Ichi
//
//  Created by Rudrank Riyam on 5/12/25.
//

import SwiftUI

@main
struct IchiApp: App {
    @State private var hasCompletedOnboarding = false
    @State private var processor = OnDeviceProcessor()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainView()
                    .environment(processor)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environment(processor)
            }
        }
#if os(macOS)
        .windowStyle(.hiddenTitleBar)
#endif
    }
}
