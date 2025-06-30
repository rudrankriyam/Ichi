import AVFoundation
import SwiftUI
import os.log

class AVSpeechTTSProvider: NSObject, TTSProvider, AVSpeechSynthesizerDelegate {
    @Published var isAudioPlaying: Bool = false
    var isAudioPlayingPublisher: Published<Bool>.Publisher { $isAudioPlaying }
    
    private let synthesizer = AVSpeechSynthesizer()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.rudrankriyam.ichi",
        category: "AVSpeechTTS"
    )
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func say(_ text: String, voice: String?, speed: Float) {
        logger.info("Starting AVSpeechSynthesizer with text of length: \(text.count)")
        
        synthesizer.stopSpeaking(at: .immediate)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speed
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        if let voice = voice,
           let voiceIdentifier = AVSpeechSynthesisVoice(language: voice) {
            utterance.voice = voiceIdentifier
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        isAudioPlaying = true
        synthesizer.speak(utterance)
    }
    
    func stopPlayback() {
        logger.info("Stopping AVSpeechSynthesizer playback")
        synthesizer.stopSpeaking(at: .immediate)
        isAudioPlaying = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        logger.info("AVSpeechSynthesizer started speaking")
        isAudioPlaying = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        logger.info("AVSpeechSynthesizer finished speaking")
        isAudioPlaying = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        logger.info("AVSpeechSynthesizer cancelled")
        isAudioPlaying = false
    }
}