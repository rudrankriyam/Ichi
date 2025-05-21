import SwiftUI
import Speech

struct WaveformView: View {
    let state: AppState
    @State private var animating = false

    var body: some View {
        if state == .listening {
            HStack(spacing: 4) {
                ForEach(0..<5) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(state.color)
                        .frame(width: 4, height: animating ? CGFloat.random(in: 10...30) : 5)
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(i) * 0.1),
                            value: animating
                        )
                }
            }
            .onAppear {
                animating = true
            }
            .onDisappear {
                animating = false
            }
        } else {
            EmptyView()
        }
    }
}

struct TypewriterView: View {
    let state: AppState
    @State private var cursorVisible = false

    var body: some View {
        if state == .transcribing {
            HStack(spacing: 0) {
                Text("abc")
                    .foregroundColor(state.color)
                Rectangle()
                    .fill(state.color)
                    .frame(width: 2, height: 16)
                    .opacity(cursorVisible ? 1 : 0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(),
                        value: cursorVisible
                    )
            }
            .onAppear {
                cursorVisible = true
            }
            .onDisappear {
                cursorVisible = false
            }
        } else {
            EmptyView()
        }
    }
}

struct ProcessingView: View {
    let state: AppState
    @State private var rotation: Double = 0

    var body: some View {
        if state == .processing {
            Image(systemName: "gearshape")
                .font(.system(size: 16))
                .foregroundColor(state.color)
                .rotationEffect(.degrees(rotation))
                .animation(
                    Animation.linear(duration: 2)
                        .repeatForever(autoreverses: false),
                    value: rotation
                )
                .onAppear {
                    rotation = 360
                }
                .onDisappear {
                    rotation = 0
                }
        } else {
            EmptyView()
        }
    }
}

struct SpeakingView: View {
    let state: AppState
    @State private var scale: CGFloat = 1.0

    var body: some View {
        if state == .playing {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 16))
                .foregroundColor(state.color)
                .scaleEffect(scale)
                .animation(
                    Animation.easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true),
                    value: scale
                )
                .onAppear {
                    scale = 1.2
                }
                .onDisappear {
                    scale = 1.0
                }
        } else {
            EmptyView()
        }
    }
}

struct MainView: View {
    @State private var currentState: AppState = .idle
    @State private var buttonScale: CGFloat = 1.0
    @State private var transcriptText: String = ""
    @Environment(\.colorScheme) private var colorScheme

    // Speech recognizer and processor
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var onDeviceProcessor = OnDeviceProcessor()

    // Handle speech recognition state transitions
    private func handleSpeechRecognition() {
        switch currentState {
        case .idle:
            // Start listening
            currentState = .listening
            Task {
                await speechRecognizer.startListening()
            }

        case .listening:
            // Stop listening and start transcribing
            currentState = .transcribing
            Task { @MainActor in
                speechRecognizer.stopListening()
                transcriptText = speechRecognizer.transcribedText

                // Move to processing after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    currentState = .processing
                    onDeviceProcessor.processTranscribedText(speechRecognizer.transcribedText)
                }
            }

        case .transcribing:
            // Skip to processing
            currentState = .processing
            onDeviceProcessor.processTranscribedText(speechRecognizer.transcribedText)

        case .processing:
            // Skip to playing
            currentState = .playing
            transcriptText = onDeviceProcessor.generatedResponse

        case .playing:
            // Reset to idle
            currentState = .idle
            speechRecognizer.reset()
            onDeviceProcessor.cancelProcessing()
        case .error:
            // Reset to idle
            currentState = .idle
            speechRecognizer.reset()
            onDeviceProcessor.cancelProcessing()
        }

        updateTranscriptText()
    }

    // Update transcript text based on speech recognizer state
    private func updateTranscriptText() {
        switch currentState {
        case .idle:
            transcriptText = "Tap the button to start a conversation"
        case .listening:
            if !speechRecognizer.transcribedText.isEmpty {
                transcriptText = speechRecognizer.transcribedText
            } else {
                transcriptText = "Listening to your voice..."
            }
        case .transcribing:
            transcriptText = "Converting your speech to text..."
        case .processing:
            transcriptText = "Thinking about your request..."
        case .playing:
            transcriptText = "Here's what I found for you..."
        case .error:
            transcriptText = "An error occurred, please try again."
        }
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                colorScheme == .dark ? Color.black : Color.white,
                colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8),
                currentState.tertiaryColor
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            // Background
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Status area
                VStack(spacing: 16) {
                    Image(systemName: currentState.SFSymbolName)
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(currentState.color)
                        .frame(width: 80, height: 80)
                        .background(
                            ZStack {
                                Circle()
                                    .fill(currentState.secondaryColor)
                                if currentState != .idle {
                                    PulsatingCircle(
                                        color: currentState.tertiaryColor,
                                        startRadius: 80,
                                        endRadius: 120
                                    )
                                }
                            }
                        )
                        .overlay(
                            Circle()
                                .stroke(currentState.color.opacity(0.3), lineWidth: 1)
                        )

                    Text(currentState.description)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(currentState.color)

                    // State-specific animation views
                    Group {
                        WaveformView(state: currentState)
                        TypewriterView(state: currentState)
                        ProcessingView(state: currentState)
                        SpeakingView(state: currentState)
                    }
                    .frame(height: 30)
                }
                .padding(.top, 60)

                // Transcript area
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transcript")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

                    Text(transcriptText)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(.darkGray).opacity(0.3) : Color(.gray))
                        )
                        .animation(.easeInOut, value: transcriptText)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)

                Spacer()

                // Main action button
                Button(action: {
                    // Haptic feedback
                    #if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    #endif

                    // Button press animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        buttonScale = 0.9
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            buttonScale = 1.0
                        }
                    }

                    // Handle speech recognition state transitions
                    handleSpeechRecognition()
                })
                {
                    ZStack {
                        // Button background
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(currentState.color, lineWidth: 2)
                            )
                            .shadow(color: currentState.color.opacity(0.3), radius: 10, x: 0, y: 5)
                            .frame(width: 80, height: 80)

                        // Button icon
                        Image(systemName: currentState == .idle ? "mic.fill" : "stop.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(currentState.color)

                        // Pulsating effect when active
                        if currentState != .idle {
                            Circle()
                                .stroke(currentState.color.opacity(0.5), lineWidth: 2)
                                .frame(width: 90, height: 90)
                                .scaleEffect(buttonScale)
                        }
                    }
                    .scaleEffect(buttonScale)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 60)
            }
            .padding(.horizontal)
        }
        .onAppear {
            updateTranscriptText()

            // Request speech recognition authorization when the view appears
            Task {
                _ = await speechRecognizer.requestAuthorization()
            }
        }
        .onChange(of: speechRecognizer.transcribedText) { _, newValue in
            if currentState == .listening && !newValue.isEmpty {
                transcriptText = newValue
            }
        }
        .onChange(of: onDeviceProcessor.generatedResponse) { _, newValue in
            if currentState == .processing && !newValue.isEmpty {
                transcriptText = newValue
            }
        }
    }
}

#Preview {
    MainView()
}
