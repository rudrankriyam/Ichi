import SwiftUI
import Combine
import os.log

@Observable
class TTSManager {
    var currentEngine: TTSEngine = .kokoro {
        didSet {
            if currentEngine != oldValue {
                updateProvider()
                savePreference()
            }
        }
    }
    
    var isAudioPlaying: Bool = false
    
    private var currentProvider: any TTSProvider
    private let kokoroProvider = KokoroTTSProvider()
    private let avSpeechProvider = AVSpeechTTSProvider()
    private var cancellable: AnyCancellable?
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.rudrankriyam.ichi",
        category: "TTSManager"
    )
    
    init() {
        // Initialize with default provider first
        currentProvider = kokoroProvider
        
        // Load user preference
        if let savedEngine = UserDefaults.standard.string(forKey: "ttsEngine"),
           let engine = TTSEngine(rawValue: savedEngine) {
            currentEngine = engine
        }
        
        // Update provider based on loaded preference
        currentProvider = currentEngine == .kokoro ? kokoroProvider : avSpeechProvider
        setupBinding()
    }
    
    private func setupBinding() {
        cancellable = currentProvider.isAudioPlayingPublisher
            .sink { [weak self] isPlaying in
                self?.isAudioPlaying = isPlaying
            }
    }
    
    private func updateProvider() {
        currentProvider.stopPlayback()
        
        switch currentEngine {
        case .kokoro:
            currentProvider = kokoroProvider
        case .avSpeech:
            currentProvider = avSpeechProvider
        }
        
        setupBinding()
        logger.info("Switched TTS engine to: \(self.currentEngine.rawValue)")
    }
    
    func say(_ text: String, voice: String? = nil, speed: Float = 1.0) {
        logger.info("Speaking text with \(self.currentEngine.rawValue)")
        currentProvider.say(text, voice: voice, speed: speed)
    }
    
    func stopPlayback() {
        currentProvider.stopPlayback()
    }
    
    private func savePreference() {
        UserDefaults.standard.set(currentEngine.rawValue, forKey: "ttsEngine")
    }
}
