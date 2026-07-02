import Foundation

@MainActor
protocol SpeechRecognizing: AnyObject {
  var transcribedText: String { get }
  var errorMessage: String? { get }

  func requestAuthorization() async -> Bool
  func startListening() async
  func stopListening()
  func reset()
}

@MainActor
protocol ConversationalResponding: AnyObject {
  var generatedResponse: String { get }

  func processTranscribedText(_ text: String) async
  func cancelProcessing()
}

@MainActor
protocol SpeechOutputting: AnyObject {
  var isAudioPlaying: Bool { get }

  func say(_ text: String, voice: String?, speed: Float)
  func stopPlayback()
}
