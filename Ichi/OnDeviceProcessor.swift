//
//  OnDeviceProcessor.swift
//  Ichi
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import SwiftUI

/// A class that handles on-device processing for conversational AI
@Observable
final class OnDeviceProcessor {
  // MARK: - Properties

  // State properties
  var isProcessing = false
  var transcribedText = ""
  var generatedResponse = ""
  var modelInfo = ""

  // Configuration properties
  let modelConfiguration = LLMRegistry.qwen3_1_7b_4bit
  let generateParameters = GenerateParameters(maxTokens: 240, temperature: 0.6)

  // MARK: - Model Loading

  enum LoadState {
    case idle
    case loaded(ModelContainer)
  }

  private var loadState = LoadState.idle

  /// Loads the model if not already loaded
  @MainActor
  func loadModel() async throws -> ModelContainer {
    switch loadState {
    case .idle:
      // Limit the buffer cache to optimize memory usage
      MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

      let modelContainer = try await LLMModelFactory.shared.loadContainer(
        configuration: modelConfiguration
      ) { [modelConfiguration] progress in
        Task { @MainActor in
          self.modelInfo =
            "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
        }
      }

      loadState = .loaded(modelContainer)
      return modelContainer

    case .loaded(let modelContainer):
      return modelContainer
    }
  }

  // MARK: - Processing Methods

  /// Process the transcribed text and generate a response
  @MainActor
  func processTranscribedText(_ text: String) async {
    guard !isProcessing else { return }

    self.transcribedText = text
    self.generatedResponse = ""

    isProcessing = true
    await generateResponse(for: text)
    isProcessing = false
  }

  /// Generate a response for the given input text
  @MainActor
  private func generateResponse(for text: String) async {
    let chat: [Chat.Message] = [
      .system("You are a helpful assistant. Keep your answers short."),
      .user(text),
    ]

    let userInput = UserInput(
      chat: chat, additionalContext: ["enable_thinking": false])

    do {
      let modelContainer = try await loadModel()

      // Set a random seed for generation
      MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

      try await modelContainer.perform { (context: ModelContext) -> Void in
        let lmInput = try await context.processor.prepare(input: userInput)
        let stream = try MLXLMCommon.generate(
          input: lmInput, parameters: generateParameters, context: context)

        // Generate and output in batches
        for await output in stream {
          if let chunk = output.chunk {
            Task { @MainActor [chunk] in
              self.generatedResponse += chunk
            }
          }
        }
      }
    } catch {
      generatedResponse = "Failed: \(error)"
    }
  }

  /// Cancel the current processing task
  @MainActor
  func cancelProcessing() {
    isProcessing = false
  }
}
