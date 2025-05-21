//
//  AppState.swift
//  Ichi
//
//  Created by Rudrank Riyam on 5/21/25.
//

import Foundation
import SwiftUI

enum AppState: CaseIterable {
    case idle
    case listening
    case transcribing
    case processing
    case playing
    case error

    var description: String {
        switch self {
        case .idle: return "Ready to Start"
        case .listening: return "Listening..."
        case .transcribing: return "Transcribing..."
        case .processing: return "Processing..."
        case .playing: return "Playing..."
        case .error: return "Error Occurred"
        }
    }

    var SFSymbolName: String {
        switch self {
        case .idle: return "mic.circle.fill"
        case .listening: return "waveform.circle.fill"
        case .transcribing: return "text.bubble.fill"
        case .processing: return "gearshape.circle.fill"
        case .playing: return "speaker.wave.2.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .idle: return Color.blue
        case .listening: return Color.blue
        case .transcribing: return Color.orange
        case .processing: return Color.purple
        case .playing: return Color.green
        case .error: return Color.red
        }
    }

    var secondaryColor: Color {
        self.color.opacity(0.2)
    }

    var tertiaryColor: Color {
        self.color.opacity(0.1)
    }
}
