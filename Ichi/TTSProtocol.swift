import Foundation
import Combine

protocol TTSProvider: ObservableObject {
    var isAudioPlaying: Bool { get }
    var isAudioPlayingPublisher: Published<Bool>.Publisher { get }
    
    func say(_ text: String, voice: String?, speed: Float)
    func stopPlayback()
}

enum TTSEngine: String, CaseIterable {
    case kokoro = "Kokoro TTS"
    case avSpeech = "System Voice"
    
    var id: String { rawValue }
}