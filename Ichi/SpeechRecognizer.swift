//
//  SpeechRecognizer.swift
//  Ichi
//
//  Created by Rudrank Riyam on 21/05/25.
//

import Foundation
import Speech
import SwiftUI
import os

#if os(macOS)
  import AVFoundation
#endif

@Observable
final class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {

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
  
  // Error tracking to prevent infinite loops
  private var consecutiveErrors = 0
  private var lastErrorTime: Date?
  private let maxConsecutiveErrors = 3
  private let errorCooldownInterval: TimeInterval = 5.0

  private let logger = Logger(subsystem: "com.rudrankriyam.Ichi", category: "SpeechRecognizer")

  override init() {
    speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.current.identifier))
    super.init()
    speechRecognizer?.delegate = self
    logger.log("SpeechRecognizer initialized.")
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
    logger.log("Requesting speech recognition authorization.")
    
    // First check microphone permissions on macOS
    #if os(macOS)
    let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    if microphoneStatus != .authorized {
      logger.error("Microphone access not authorized on macOS: \(microphoneStatus.rawValue)")
      if microphoneStatus == .notDetermined {
        // Request microphone access first
        let granted = await withCheckedContinuation { continuation in
          AVCaptureDevice.requestAccess(for: .audio) { granted in
            continuation.resume(returning: granted)
          }
        }
        if !granted {
          logger.error("Microphone access denied by user on macOS")
          errorMessage = "Microphone access is required for speech recognition. Please allow microphone access in System Settings."
          return false
        }
      } else {
        logger.error("Microphone access previously denied on macOS")
        errorMessage = "Microphone access denied. Please enable microphone access in System Settings > Privacy & Security > Microphone."
        return false
      }
    }
    #endif
    
    do {
      // Add completion handler to make it work with async/await
      let status = try await withCheckedThrowingContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
          continuation.resume(returning: status)
        }
      }
      let authorized = status == .authorized
      logger.log(
        "Speech recognition authorization status: \(authorized ? "Authorized" : "Not Authorized")")
      
      if !authorized {
        switch status {
        case .denied:
          errorMessage = "Speech recognition access denied. Please enable it in Settings."
        case .restricted:
          errorMessage = "Speech recognition is restricted on this device."
        case .notDetermined:
          errorMessage = "Speech recognition authorization not determined."
        case .authorized:
          break // This case is already handled above
        @unknown default:
          errorMessage = "Unknown speech recognition authorization status."
        }
      }
      
      return authorized
    } catch {
      logger.error("Failed to request authorization: \(error.localizedDescription)")
      errorMessage = "Failed to request authorization: \(error.localizedDescription)"
      return false
    }
  }

  /// Configure audio session based on platform
  private func configureAudioSession() throws {
    #if os(iOS)
      logger.log("Configuring audio session for iOS.")
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
      logger.log("Audio session configured and activated.")
    #else
      logger.log("Configuring audio for macOS.")
      // Log available input devices for debugging
      logMacOSAudioDevices()
      // Check macOS permissions
      checkMacOSPermissions()
      logger.log("macOS audio configuration completed.")
    #endif
  }

  #if os(macOS)
    /// Log information about available audio devices on macOS
    private func logMacOSAudioDevices() {
      logger.log("Checking macOS audio devices...")

      // Get list of audio devices using the modern API
      let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.microphone, .external],
        mediaType: .audio,
        position: .unspecified
      )
      let devices = discoverySession.devices
      logger.log("Found \(devices.count) macOS audio input devices:")

      for (index, device) in devices.enumerated() {
        logger.log("Device \(index+1): \(device.localizedName) (ID: \(device.uniqueID))")
      }

      // Check if we have any input devices
      if devices.isEmpty {
        logger.error("No audio input devices found on macOS")
      } else {
        logger.log("Default device should be: \(devices.first?.localizedName ?? "Unknown")")
      }
    }

    /// Check for macOS-specific permissions
    private func checkMacOSPermissions() {
      logger.log("Checking macOS permissions...")

      // Check for microphone permissions on macOS
      switch AVCaptureDevice.authorizationStatus(for: .audio) {
      case .authorized:
        logger.log("macOS microphone access is authorized")
      case .notDetermined:
        logger.log("macOS microphone access not determined, requesting access")
        AVCaptureDevice.requestAccess(for: .audio) { [self] granted in
          self.logger.log("macOS microphone access \(granted ? "granted" : "denied")")
        }
      case .denied:
        logger.error("macOS microphone access denied")
      case .restricted:
        logger.error("macOS microphone access restricted")
      @unknown default:
        logger.error("Unknown macOS microphone access status")
      }
    }
  #endif

  // MARK: - Speech Recognition Methods

  /// Start listening and transcribing speech
  @MainActor
  func startListening() async {
    logger.log("Attempting to start listening.")
    // Check if already listening
    guard !isListening else {
      logger.warning("Already listening, startListening() aborted.")
      return
    }

    // Check authorization
    let isAuthorized = await requestAuthorization()
    guard isAuthorized else {
      logger.error("Speech recognition not authorized. Cannot start listening.")
      recognitionState = .error
      errorMessage = "Speech recognition not authorized"
      return
    }

    // Check if speech recognizer is available
    guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
      logger.error("Speech recognizer not available. Cannot start listening.")
      recognitionState = .error
      errorMessage = "Speech recognizer not available"
      return
    }

    do {
      logger.log("Configuring audio session and recognition request.")
      // Configure audio session
      try configureAudioSession()

      // Clear previous task if any
      if recognitionTask != nil {
        logger.log("Cancelling previous recognition task.")
        recognitionTask?.cancel()
        recognitionTask = nil
      }

      // Create and configure the speech recognition request
      recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
      guard let recognitionRequest = recognitionRequest else {
        logger.critical("Unable to create SFSpeechAudioBufferRecognitionRequest.")
        throw NSError(
          domain: "SpeechRecognizerErrorDomain", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
      }

      recognitionRequest.shouldReportPartialResults = true
      logger.log("Recognition request configured for partial results.")

      // Configure audio input
      let inputNode = audioEngine.inputNode
      let recordingFormat = inputNode.outputFormat(forBus: 0)
      logger.log("Audio input node recording format: \(recordingFormat.description)")

      #if os(macOS)
        // macOS-specific logging and configuration
        logger.log("macOS input node details: \(inputNode)")
        logger.log(
          "macOS input node channels: \(recordingFormat.channelCount), sample rate: \(recordingFormat.sampleRate)"
        )

        // Check if the audio engine has input
        if audioEngine.inputNode.numberOfInputs == 0 {
          logger.error("macOS audio engine has no inputs available")
          throw NSError(
            domain: "SpeechRecognizerErrorDomain", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No audio input available on this Mac"])
        }
      #endif

      inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
        [weak self] buffer, _ in
        self?.recognitionRequest?.append(buffer)
      }
      logger.log("Input node tap installed.")

      // Start audio engine
      audioEngine.prepare()

      do {
        try audioEngine.start()
        logger.log("Audio engine started successfully.")

        // Introduce a small delay to allow the audio engine to stabilize
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

      } catch {
        logger.error("Failed to start audio engine: \(error.localizedDescription)")
        #if os(macOS)
          // Additional macOS-specific error handling
          let nsError = error as NSError
          logger.error(
            "macOS audio engine error - domain: \(nsError.domain), code: \(nsError.code)")

          // Check for common macOS issues
          if nsError.domain == NSOSStatusErrorDomain {
            logger.error(
              "macOS audio status error. This often means permission issues or no input device.")
            throw NSError(
              domain: "SpeechRecognizerErrorDomain", code: 2,
              userInfo: [
                NSLocalizedDescriptionKey:
                  "Could not access microphone. Please check your Mac's privacy settings."
              ])
          }
        #endif
        throw error
      }

      recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) {
        [weak self] result, error in
        guard let self = self else { return }

        var isFinal = false

        if let result = result {
          Task { @MainActor in
            self.logger.debug(
              "Partial transcription: \"\(result.bestTranscription.formattedString)\"")
            self.transcribedText = result.bestTranscription.formattedString
            self.recognitionState = .transcribing
          }
          isFinal = result.isFinal
        }

        if let error = error {
          self.logger.error("Recognition task error: \(error.localizedDescription)")
          // Enhanced error logging
          let nsError = error as NSError
          self.logger.error("Detailed Error - Domain: \(nsError.domain), Code: \(nsError.code), UserInfo: \(nsError.userInfo)")

          // Track consecutive errors to prevent infinite loops
          let now = Date()
          if let lastError = self.lastErrorTime, now.timeIntervalSince(lastError) < self.errorCooldownInterval {
            self.consecutiveErrors += 1
          } else {
            self.consecutiveErrors = 1
          }
          self.lastErrorTime = now
          
          // If we've had too many consecutive errors, stop trying
          if self.consecutiveErrors >= self.maxConsecutiveErrors {
            self.logger.critical("Too many consecutive errors (\(self.consecutiveErrors)). Stopping speech recognition to prevent infinite loop.")
            Task { @MainActor in
              self.reset()
              self.errorMessage = "Speech recognition has encountered repeated errors. Please restart the app or check your system permissions."
              self.recognitionState = .error
            }
            return
          }

          if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101 {
            self.logger.critical("CRITICAL: Received 1101 error. This indicates a failure in the speech recording client. Check microphone access and audio configuration.")
            
            // For error 1101, provide specific guidance but don't retry automatically
            Task { @MainActor in
              self.reset()
              #if os(macOS)
              self.errorMessage = "Microphone access denied. Please go to System Settings > Privacy & Security > Microphone and allow access for this app, then restart the app."
              #else
              self.errorMessage = "Microphone access issue detected. Please check your system permissions in Settings > Privacy & Security."
              #endif
              self.recognitionState = .error
            }
            return
          }
          
          // Handle specific error cases
          if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 203 {
            self.logger.warning("Received kAFAssistantErrorDomain code 203. Retrying...")
            // Only retry if we haven't had too many errors
            if self.consecutiveErrors < 2 {
              Task { @MainActor in
                self.reset()
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second delay
                await self.startListening()
              }
              return
            }
          }

          Task { @MainActor in
            self.errorMessage = "Recognition error: \(error.localizedDescription)"
            self.recognitionState = .error
          }
        }

        if isFinal {
          Task { @MainActor in
            self.logger.log("Final transcription received. Stopping audio engine and cleaning up.")
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)
            self.recognitionRequest = nil
            self.recognitionTask = nil
            self.isListening = false
            self.recognitionState = .finished
            self.logger.log("Recognition finished. Transcribed text: \"\(self.transcribedText)\"")
          }
        }
      }
      logger.log("Recognition task started.")

      // Update state
      transcribedText = ""
      isListening = true
      recognitionState = .listening
      errorMessage = nil
      
      // Reset error tracking on successful start
      consecutiveErrors = 0
      lastErrorTime = nil
      
      logger.log("SpeechRecognizer is now listening.")

    } catch {
      logger.error("Failed to start recognition: \(error.localizedDescription)")
      // Handle setup errors
      recognitionState = .error
      errorMessage = "Failed to start recognition: \(error.localizedDescription)"
      // Ensure cleanup if something went wrong during setup
      audioEngine.stop()
      audioEngine.inputNode.removeTap(onBus: 0)
      recognitionRequest = nil
      recognitionTask = nil
      isListening = false
    }
  }

  /// Stop listening and finalize transcription
  @MainActor
  func stopListening() {
    logger.log("Stop listening requested.")
    // Stop audio engine and recognition
    if audioEngine.isRunning {
      audioEngine.stop()
      logger.log("Audio engine stopped.")
    }
    recognitionRequest?.endAudio()
    logger.log("Recognition request endAudio called.")

    // Update state
    isListening = false
    recognitionState = .finished  // Or determine based on task if it's still running somehow
    logger.log("SpeechRecognizer stopped listening. State: \(self.recognitionState.description)")
  }

  /// Reset the recognizer state
  @MainActor
  func reset() {
    logger.log("Resetting SpeechRecognizer state.")
    // Cancel any ongoing tasks
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil
    logger.log("Recognition task and request cancelled/nilled.")

    // Stop audio if running
    if audioEngine.isRunning {
      audioEngine.stop()
      logger.log("Audio engine stopped.")
    }

    audioEngine.inputNode.removeTap(onBus: 0)
    logger.log("Input node tap removed (if one existed).")

    // Reset state
    isListening = false
    transcribedText = ""
    recognitionState = .idle
    errorMessage = nil
    logger.log("SpeechRecognizer state reset to idle.")
  }

  // MARK: - SFSpeechRecognizerDelegate

  func speechRecognizer(
    _ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool
  ) {
    logger.log("Speech recognizer availability changed: \(available ? "Available" : "Unavailable")")
    if !available {
      Task { @MainActor in
        isListening = false
        recognitionState = .error
        errorMessage = "Speech recognition not available"
        logger.error("Speech recognition became unavailable.")
      }
    }
  }
}
