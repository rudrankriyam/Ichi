import Testing
@testable import IchiConversation

@Suite("Speech recognition request factory")
struct SpeechRecognitionRequestFactoryTests {
  @Test("requires on-device recognition")
  func requiresOnDeviceRecognition() {
    let request = SpeechRecognitionRequestFactory.makeAudioBufferRecognitionRequest()

    #expect(request.requiresOnDeviceRecognition)
    #expect(request.shouldReportPartialResults)
  }
}
