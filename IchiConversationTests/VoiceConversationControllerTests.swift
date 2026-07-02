import Testing
@testable import IchiConversation

@MainActor
@Suite("Voice conversation controller")
struct VoiceConversationControllerTests {
  @Test("starts in idle with a helpful prompt")
  func initialState() {
    let controller = makeController().controller

    #expect(controller.state == .idle)
    #expect(controller.transcriptText == "Tap the button to start a conversation")
  }

  @Test("starts listening from idle")
  func startsListening() async {
    let testRig = makeController()

    await testRig.controller.handlePrimaryAction()

    #expect(testRig.controller.state == .listening)
    #expect(testRig.recognizer.startCallCount == 1)
    #expect(testRig.controller.transcriptText == "Listening to your voice...")
  }

  @Test("turns a transcript into speech")
  func respondsToTranscript() async {
    let testRig = makeController()
    testRig.recognizer.transcribedText = "What can I build today?"
    testRig.responder.response = "A small voice agent builder."

    await testRig.controller.handlePrimaryAction()
    await testRig.controller.handlePrimaryAction()

    #expect(testRig.recognizer.stopCallCount == 1)
    #expect(testRig.responder.processedText == "What can I build today?")
    #expect(testRig.speaker.spokenTexts == ["A small voice agent builder."])
    #expect(testRig.controller.state == .playing)
    #expect(testRig.controller.transcriptText == "A small voice agent builder.")
  }

  @Test("keeps the generated response visible while playing")
  func generatedResponseStaysVisibleWhilePlaying() async {
    let testRig = makeController()
    testRig.recognizer.transcribedText = "What should stay on screen?"
    testRig.responder.response = "The generated response should stay visible."

    await testRig.controller.handlePrimaryAction()
    await testRig.controller.handlePrimaryAction()
    try? await Task.sleep(for: .milliseconds(180))

    #expect(testRig.controller.state == .playing)
    #expect(testRig.controller.transcriptText == "The generated response should stay visible.")
  }

  @Test("short playback returns to idle")
  func shortPlaybackReturnsToIdle() async {
    let testRig = makeController()
    testRig.recognizer.transcribedText = "Say something quick"
    testRig.responder.response = "Done."
    testRig.speaker.startsPlayingOnSay = false

    await testRig.controller.handlePrimaryAction()
    await testRig.controller.handlePrimaryAction()
    try? await Task.sleep(for: .milliseconds(180))

    #expect(testRig.controller.state == .idle)
    #expect(testRig.controller.transcriptText == "Tap the button to start a conversation")
  }

  @Test("reset during processing prevents stale speech")
  func resetDuringProcessingPreventsStaleSpeech() async {
    let testRig = makeController()
    testRig.recognizer.transcribedText = "Tell me something slow"
    testRig.responder.response = "This should not be spoken."
    testRig.responder.shouldWaitForRelease = true

    await testRig.controller.handlePrimaryAction()

    let processingTask = Task {
      await testRig.controller.handlePrimaryAction()
    }

    await testRig.responder.waitUntilSuspended()
    await testRig.controller.handlePrimaryAction()
    testRig.responder.release()
    await processingTask.value

    #expect(testRig.controller.state == .idle)
    #expect(testRig.responder.cancelCallCount == 1)
    #expect(testRig.speaker.stopCallCount == 1)
    #expect(testRig.speaker.spokenTexts.isEmpty)
  }

  private func makeController() -> TestRig {
    let recognizer = FakeSpeechRecognizer()
    let responder = FakeResponder()
    let speaker = FakeSpeechOutput()
    let controller = VoiceConversationController(
      speechRecognizer: recognizer,
      responder: responder,
      speechOutput: speaker
    )

    return TestRig(
      controller: controller,
      recognizer: recognizer,
      responder: responder,
      speaker: speaker
    )
  }
}

@MainActor
private struct TestRig {
  let controller: VoiceConversationController
  let recognizer: FakeSpeechRecognizer
  let responder: FakeResponder
  let speaker: FakeSpeechOutput
}

@MainActor
private final class FakeSpeechRecognizer: SpeechRecognizing {
  var transcribedText = ""
  var errorMessage: String?
  var startCallCount = 0
  var stopCallCount = 0
  var resetCallCount = 0

  func requestAuthorization() async -> Bool {
    true
  }

  func startListening() async {
    startCallCount += 1
  }

  func stopListening() {
    stopCallCount += 1
  }

  func reset() {
    resetCallCount += 1
    transcribedText = ""
    errorMessage = nil
  }
}

@MainActor
private final class FakeResponder: ConversationalResponding {
  var generatedResponse = ""
  var response = "Response"
  var processedText: String?
  var cancelCallCount = 0
  var shouldWaitForRelease = false

  private var suspendedContinuation: CheckedContinuation<Void, Never>?
  private var releaseContinuation: CheckedContinuation<Void, Never>?

  func processTranscribedText(_ text: String) async {
    processedText = text

    if shouldWaitForRelease {
      await withCheckedContinuation { continuation in
        releaseContinuation = continuation
        suspendedContinuation?.resume()
        suspendedContinuation = nil
      }
    }

    generatedResponse = response
  }

  func cancelProcessing() {
    cancelCallCount += 1
  }

  func waitUntilSuspended() async {
    if releaseContinuation != nil {
      return
    }

    await withCheckedContinuation { continuation in
      suspendedContinuation = continuation
    }
  }

  func release() {
    releaseContinuation?.resume()
    releaseContinuation = nil
  }
}

@MainActor
private final class FakeSpeechOutput: SpeechOutputting {
  var isAudioPlaying = false
  var spokenTexts: [String] = []
  var startsPlayingOnSay = true
  var stopCallCount = 0

  func say(_ text: String, voice: String?, speed: Float) {
    spokenTexts.append(text)
    isAudioPlaying = startsPlayingOnSay
  }

  func stopPlayback() {
    stopCallCount += 1
    isAudioPlaying = false
  }
}
