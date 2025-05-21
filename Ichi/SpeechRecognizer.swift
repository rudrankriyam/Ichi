//
//  SpeechRecognizer.swift
//  Ichi
//

import Foundation
import Speech
import SwiftUI

/// A class that handles speech recognition using Apple's Speech framework
@Observable
final class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    // MARK: - Properties

    // State properties
    var isListening = false
    var transcribedText = ""
    var recognitionState: RecognitionState = .idle
    var errorMessage: String? = nil

    // Speech recognition properties
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Initialization

    override init() {
        // Initialize with the user's locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.current.identifier))
        super.init()
        speechRecognizer?.delegate = self
    }

    // MARK: - Recognition State

    /// Represents the current state of speech recognition
    enum RecognitionState {
        case idle
        case listening
        case transcribing
        case finished
        case error

        var description: String {
            switch self {
            case .idle: return "Ready to listen"
            case .listening: return "Listening..."
            case .transcribing: return "Transcribing..."
            case .finished: return "Finished"
            case .error: return "Error occurred"
            }
        }
    }

    // MARK: - Authorization

    /// Request authorization for speech recognition
    func requestAuthorization() async -> Bool {
        do {
            // Add completion handler to make it work with async/await
            let status = try await withCheckedThrowingContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            return status == .authorized
        } catch {
            errorMessage = "Failed to request authorization: \(error.localizedDescription)"
            return false
        }
    }

    /// Configure audio session based on platform
    private func configureAudioSession() throws {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }

    // MARK: - Speech Recognition Methods

    /// Start listening and transcribing speech
    @MainActor
    func startListening() async {
        // Check if already listening
        guard !isListening else { return }

        // Check authorization
        let isAuthorized = await requestAuthorization()
        guard isAuthorized else {
            recognitionState = .error
            errorMessage = "Speech recognition not authorized"
            return
        }

        // Check if speech recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            recognitionState = .error
            errorMessage = "Speech recognizer not available"
            return
        }

        do {
            // Configure audio session
            try configureAudioSession()

            // Clear previous task if any
            recognitionTask?.cancel()
            recognitionTask = nil

            // Create and configure the speech recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                throw NSError(domain: "SpeechRecognizerErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
            }

            recognitionRequest.shouldReportPartialResults = true

            // Configure audio input
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            // Start audio engine
            audioEngine.prepare()
            try audioEngine.start()

            // Start recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                var isFinal = false

                if let result = result {
                    // Update transcribed text
                    Task { @MainActor in
                        self.transcribedText = result.bestTranscription.formattedString
                        self.recognitionState = .transcribing
                    }
                    isFinal = result.isFinal
                }

                // Handle completion or error
                if error != nil || isFinal {
                    Task { @MainActor in
                        self.audioEngine.stop()
                        inputNode.removeTap(onBus: 0)

                        self.recognitionRequest = nil
                        self.recognitionTask = nil

                        self.isListening = false
                        self.recognitionState = isFinal ? .finished : .error

                        if let error = error {
                            self.errorMessage = "Recognition error: \(error.localizedDescription)"
                        }
                    }
                }
            }

            // Update state
            transcribedText = ""
            isListening = true
            recognitionState = .listening
            errorMessage = nil

        } catch {
            // Handle setup errors
            recognitionState = .error
            errorMessage = "Failed to start recognition: \(error.localizedDescription)"
        }
    }

    /// Stop listening and finalize transcription
    @MainActor
    func stopListening() {
        // Stop audio engine and recognition
        audioEngine.stop()
        recognitionRequest?.endAudio()

        // Update state
        isListening = false
        recognitionState = .finished
    }

    /// Reset the recognizer state
    @MainActor
    func reset() {
        // Cancel any ongoing tasks
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // Stop audio if running
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // Reset state
        isListening = false
        transcribedText = ""
        recognitionState = .idle
        errorMessage = nil
    }

    // MARK: - SFSpeechRecognizerDelegate

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            Task { @MainActor in
                isListening = false
                recognitionState = .error
                errorMessage = "Speech recognition not available"
            }
        }
    }
}
