import Foundation
import Observation
import os

@MainActor
@Observable
final class VoiceConversationController {
  var state: AppState = .idle
  var transcriptText = ""

  @ObservationIgnored private let speechRecognizer: any SpeechRecognizing
  @ObservationIgnored private let responder: any ConversationalResponding
  @ObservationIgnored private let speechOutput: any SpeechOutputting
  @ObservationIgnored private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.rudrankriyam.ichi",
    category: "VoiceConversation"
  )

  @ObservationIgnored private var mirrorTask: Task<Void, Never>?
  @ObservationIgnored private var playbackTask: Task<Void, Never>?
  @ObservationIgnored private var activeRunID = UUID()

  init(
    speechRecognizer: any SpeechRecognizing,
    responder: any ConversationalResponding,
    speechOutput: any SpeechOutputting
  ) {
    self.speechRecognizer = speechRecognizer
    self.responder = responder
    self.speechOutput = speechOutput
    updateTranscriptText()
  }

  deinit {
    mirrorTask?.cancel()
    playbackTask?.cancel()
  }

  func requestSpeechAuthorization() async {
    _ = await speechRecognizer.requestAuthorization()
  }

  func handlePrimaryAction() async {
    switch state {
    case .idle:
      await startListening()

    case .listening:
      await finishListeningAndRespond()

    case .transcribing, .processing, .playing, .error:
      resetConversation()
    }
  }

  func refreshTranscriptFromDependencies() {
    switch state {
    case .listening:
      let recognizedText = speechRecognizer.transcribedText
      transcriptText = recognizedText.isEmpty ? "Listening to your voice..." : recognizedText

    case .processing:
      let generatedResponse = responder.generatedResponse
      transcriptText = generatedResponse.isEmpty ? "Thinking about your request..." : generatedResponse

    default:
      updateTranscriptText()
    }
  }

  private func startListening() async {
    beginNewRun()
    state = .listening
    updateTranscriptText()
    startMirroringDependencyText()

    await speechRecognizer.startListening()

    if speechRecognizer.errorMessage != nil {
      state = .error
      updateTranscriptText()
      stopMirroringDependencyText()
    }
  }

  private func finishListeningAndRespond() async {
    state = .transcribing
    updateTranscriptText()
    speechRecognizer.stopListening()

    let requestText = speechRecognizer.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !requestText.isEmpty else {
      resetConversation(message: "I didn't catch that. Tap the button to try again.")
      return
    }

    let runID = activeRunID
    state = .processing
    updateTranscriptText()

    await responder.processTranscribedText(requestText)
    guard activeRunID == runID, !Task.isCancelled else { return }

    let response = responder.generatedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !response.isEmpty else {
      state = .error
      transcriptText = "No response was generated. Please try again."
      return
    }

    speak(response, runID: runID)
  }

  private func speak(_ text: String, runID: UUID) {
    state = .playing
    transcriptText = text
    logger.info("Starting text-to-speech for generated response")
    speechOutput.say(text, voice: nil, speed: 1.0)
    startPlaybackMonitor(runID: runID)
  }

  private func resetConversation(message: String? = nil) {
    beginNewRun()
    speechRecognizer.reset()
    responder.cancelProcessing()
    speechOutput.stopPlayback()
    state = .idle
    transcriptText = message ?? "Tap the button to start a conversation"
  }

  private func beginNewRun() {
    activeRunID = UUID()
    stopMirroringDependencyText()
    playbackTask?.cancel()
    playbackTask = nil
  }

  private func updateTranscriptText() {
    switch state {
    case .idle:
      transcriptText = "Tap the button to start a conversation"
    case .listening:
      transcriptText = "Listening to your voice..."
    case .transcribing:
      transcriptText = "Converting your speech to text..."
    case .processing:
      transcriptText = "Thinking about your request..."
    case .playing:
      transcriptText = "Here's what I found for you..."
    case .error:
      transcriptText = speechRecognizer.errorMessage ?? "An error occurred, please try again."
    }
  }

  private func startMirroringDependencyText() {
    stopMirroringDependencyText()

    mirrorTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        self?.refreshTranscriptFromDependencies()
        try? await Task.sleep(for: .milliseconds(120))
      }
    }
  }

  private func stopMirroringDependencyText() {
    mirrorTask?.cancel()
    mirrorTask = nil
  }

  private func startPlaybackMonitor(runID: UUID) {
    playbackTask?.cancel()

    playbackTask = Task { @MainActor [weak self] in
      var playbackStarted = false

      while !Task.isCancelled {
        guard let self, self.activeRunID == runID, self.state == .playing else {
          return
        }

        if self.speechOutput.isAudioPlaying {
          playbackStarted = true
        } else if playbackStarted {
          self.state = .idle
          self.updateTranscriptText()
          return
        }

        try? await Task.sleep(for: .milliseconds(150))
      }
    }
  }
}
