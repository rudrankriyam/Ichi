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
import Tokenizers

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
    var modelConfiguration = LLMRegistry.qwen3_1_7b_4bit
    var generateParameters = GenerateParameters(maxTokens: 240, temperature: 0.6)
    let updateInterval = Duration.seconds(0.25)

    // Tool configuration
    var includeWeatherTool = false
    var enableThinking = false

    // Processing task
    private var processingTask: Task<Void, Error>?

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
                    self.modelInfo = "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                }
            }

            let numParams = await modelContainer.perform { context in
                context.model.numParameters()
            }

            self.modelInfo = "Loaded \(modelConfiguration.name)"
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

       // processingTask = Task {
            isProcessing = true
            await generateResponse(for: text)
            isProcessing = false
     //   }
    }

    /// Generate a response for the given input text
    @MainActor
    private func generateResponse(for text: String) async {
        let chat: [Chat.Message] = [
            .system("You are a helpful assistant"),
            .user(text),
        ]

        let userInput = UserInput(
            chat: chat, additionalContext: ["enable_thinking": enableThinking])

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
        processingTask?.cancel()
        isProcessing = false
    }

    // MARK: - Tool Definitions

    let currentWeatherToolSpec: [String: any Sendable] =
    [
        "type": "function",
        "function": [
            "name": "get_current_weather",
            "description": "Get the current weather in a given location",
            "parameters": [
                "type": "object",
                "properties": [
                    "location": [
                        "type": "string",
                        "description": "The city and state, e.g. San Francisco, CA",
                    ] as [String: String],
                    "unit": [
                        "type": "string",
                        "enum": ["celsius", "fahrenheit"],
                    ] as [String: any Sendable],
                ] as [String: [String: any Sendable]],
                "required": ["location"],
            ] as [String: any Sendable],
        ] as [String: any Sendable],
    ] as [String: any Sendable]

    // MARK: - Conversation State Management

    /// Represents the current state of the conversation
    enum ConversationState {
        case idle
        case listening
        case transcribing
        case processing
        case speaking

        var description: String {
            switch self {
            case .idle: return "Idle"
            case .listening: return "Listening"
            case .transcribing: return "Transcribing"
            case .processing: return "Processing"
            case .speaking: return "Speaking"
            }
        }
    }

    var conversationState: ConversationState = .idle
}
