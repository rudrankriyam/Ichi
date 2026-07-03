import Speech

enum SpeechRecognitionRequestFactory {
  static func makeAudioBufferRecognitionRequest() -> SFSpeechAudioBufferRecognitionRequest {
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = true
    return request
  }
}
