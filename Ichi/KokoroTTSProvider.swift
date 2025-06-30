import Foundation
import Swift_TTS
import MLX
import Combine
import os.log

class KokoroTTSProvider: TTSProvider {
    @Published var isAudioPlaying: Bool = false
    var isAudioPlayingPublisher: Published<Bool>.Publisher { $isAudioPlaying }
    
    private let kokoroModel = KokoroTTSModel()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.rudrankriyam.ichi",
        category: "KokoroTTS"
    )
    private var cancellable: AnyCancellable?
    
    init() {
        cancellable = kokoroModel.$isAudioPlaying
            .sink { [weak self] isPlaying in
                self?.isAudioPlaying = isPlaying
            }
    }
    
    func say(_ text: String, voice: String?, speed: Float) {
        logger.info("Starting Kokoro TTS with text of length: \(text.count)")
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
        kokoroModel.say(text, .afJessica, speed: speed)
    }
    
    func stopPlayback() {
        logger.info("Stopping Kokoro TTS playback")
        kokoroModel.stopPlayback()
    }
}