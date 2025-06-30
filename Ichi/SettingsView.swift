import SwiftUI

struct SettingsView: View {
    @Bindable var ttsManager: TTSManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Voice Engine", selection: $ttsManager.currentEngine) {
                        ForEach(TTSEngine.allCases, id: \.self) { engine in
                            Text(engine.rawValue)
                                .tag(engine)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text(engineDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Text-to-Speech")
                } footer: {
                    Text("Choose between high-quality Kokoro TTS or the built-in system voice.")
                }
                
                Section {
                    Button("Test Voice") {
                        ttsManager.say("Hello! This is a test of the \(ttsManager.currentEngine.rawValue) voice engine.")
                    }
                    .foregroundColor(.blue)
                    
                    if ttsManager.isAudioPlaying {
                        Button("Stop") {
                            ttsManager.stopPlayback()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var engineDescription: String {
        switch ttsManager.currentEngine {
        case .kokoro:
            return "High-quality neural voice synthesis running on-device"
        case .avSpeech:
            return "System voice using AVSpeechSynthesizer"
        }
    }
}

