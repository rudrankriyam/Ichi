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
@MainActor
@Observable
final class OnDeviceProcessor {
  // MARK: - Properties

  // State properties
  var isProcessing = false
  var transcribedText = ""
  var generatedResponse = ""
  var processingError: String? = nil
  var modelInfo = ""

  // Configuration properties
  let configuration: OnDeviceProcessorConfiguration

  // Generation lifecycle
  @ObservationIgnored private var generationTask: Task<Void, Never>?
  @ObservationIgnored private var activeGenerationID = UUID()

  init(configuration: OnDeviceProcessorConfiguration = .ichiDefault) {
    self.configuration = configuration
  }

  // MARK: - Model Loading

  enum LoadState {
    case idle
    case loaded(ModelContainer)
  }

  private var loadState = LoadState.idle

  /// Loads the model if not already loaded
  func loadModel() async throws -> ModelContainer {
    switch loadState {
    case .idle:
      // Limit the buffer cache to optimize memory usage
      MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

      let modelContainer = try await LLMModelFactory.shared.loadContainer(
        configuration: configuration.model
      ) { [configuration] progress in
        Task { @MainActor in
          self.modelInfo =
            "Downloading \(configuration.model.name): \(Int(progress.fractionCompleted * 100))%"
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
  func processTranscribedText(_ text: String) async {
    guard !isProcessing else { return }

    self.transcribedText = text
    self.generatedResponse = ""
    self.processingError = nil

    let generationID = UUID()
    activeGenerationID = generationID
    isProcessing = true

    let task = Task { [weak self] in
      guard let self else { return }
      await self.generateResponse(for: text, generationID: generationID)
    }
    generationTask = task
    await task.value

    // Only the run that is still current may flip the processing flag back;
    // a cancelled run must not clobber the state of a newer run.
    if activeGenerationID == generationID {
      isProcessing = false
      generationTask = nil
    }
  }

  /// Generate a response for the given input text
  private func generateResponse(for text: String, generationID: UUID) async {
    let chat: [Chat.Message] = [
      .system(configuration.systemPrompt),
      .user(text),
    ]

    let userInput = UserInput(
      chat: chat, additionalContext: ["enable_thinking": configuration.enableThinking])

    do {
      let modelContainer = try await loadModel()

      // Set a random seed for generation
      MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

      // Token chunks are funneled through a single AsyncStream consumed by one
      // MainActor task, so appends happen exactly in generation order.
      let (chunks, chunkContinuation) = AsyncStream.makeStream(of: String.self)

      let consumer = Task { @MainActor [weak self] in
        for await chunk in chunks {
          guard let self, self.activeGenerationID == generationID else { return }
          self.generatedResponse += chunk
        }
      }

      var generationError: Error?
      do {
        try await modelContainer.perform { (context: ModelContext) -> Void in
          let lmInput = try await context.processor.prepare(input: userInput)
          let stream = try MLXLMCommon.generate(
            input: lmInput, parameters: configuration.generateParameters, context: context)

          // Generate and output in batches, stopping as soon as the run is cancelled.
          for await output in stream {
            if Task.isCancelled { break }
            if let chunk = output.chunk {
              chunkContinuation.yield(chunk)
            }
          }
        }
      } catch {
        generationError = error
      }

      chunkContinuation.finish()
      await consumer.value

      if let generationError {
        throw generationError
      }
    } catch is CancellationError {
      // Cancelled runs end silently; the UI state is handled by the caller.
    } catch {
      // Route errors to a dedicated property instead of the response text so
      // downstream consumers (like TTS) never speak raw error descriptions.
      guard activeGenerationID == generationID else { return }
      processingError = error.localizedDescription
    }
  }

  /// Cancel the current processing task
  func cancelProcessing() {
    activeGenerationID = UUID()
    generationTask?.cancel()
    generationTask = nil
    isProcessing = false
  }
}

struct OnDeviceProcessorConfiguration: Sendable {
  let model: ModelConfiguration
  let systemPrompt: String
  let generateParameters: GenerateParameters
  let enableThinking: Bool

  static let ichiDefault = OnDeviceProcessorConfiguration(
    model: LLMRegistry.qwen3_1_7b_4bit,
    systemPrompt: "You are a helpful assistant. Keep your answers short.",
    generateParameters: GenerateParameters(maxTokens: 240, temperature: 0.6),
    enableThinking: false
  )
}
