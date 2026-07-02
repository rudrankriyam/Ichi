import SwiftUI

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
  @State private var conversation: VoiceConversationController
  @State private var ttsManager: TTSManager
  @State private var buttonScale: CGFloat = 1.0
  @State private var showingSettings = false
  @Environment(\.colorScheme) private var colorScheme

  init(processor: OnDeviceProcessor) {
    let ttsManager = TTSManager()
    _ttsManager = State(initialValue: ttsManager)
    _conversation = State(
      initialValue: VoiceConversationController(
        speechRecognizer: SpeechRecognizer(),
        responder: processor,
        speechOutput: ttsManager
      )
    )
  }

  var backgroundGradient: LinearGradient {
    LinearGradient(
      gradient: Gradient(colors: [
        colorScheme == .dark ? Color.black : Color.white,
        colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8),
        conversation.state.tertiaryColor,
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
        // Settings button in top right
        HStack {
          Spacer()
          Button(action: {
            showingSettings = true
          }) {
            Image(systemName: "gearshape.fill")
              .font(.system(size: 20))
              .foregroundColor(.secondary)
              .padding(12)
              .background(Circle().fill(.ultraThinMaterial))
          }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        // Status area
        VStack(spacing: 16) {
          Image(systemName: conversation.state.SFSymbolName)
            .font(.system(size: 36, weight: .light))
            .foregroundColor(conversation.state.color)
            .frame(width: 80, height: 80)
            .background(
              ZStack {
                Circle()
                  .fill(conversation.state.secondaryColor)
                if conversation.state != .idle {
                  PulsatingCircle(
                    color: conversation.state.tertiaryColor,
                    startRadius: 80,
                    endRadius: 120
                  )
                }
              }
            )
            .overlay(
              Circle()
                .stroke(conversation.state.color.opacity(0.3), lineWidth: 1)
            )

          Text(conversation.state.description)
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .foregroundColor(conversation.state.color)

          // State-specific animation views
          Group {
            WaveformView(state: conversation.state)
            TypewriterView(state: conversation.state)
            ProcessingView(state: conversation.state)
            SpeakingView(state: conversation.state)
          }
          .frame(height: 30)
        }

        // Transcript area
        VStack(alignment: .leading, spacing: 12) {
          Text("Transcript")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.leading, 4)

          Text(conversation.transcriptText)
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(conversation.state.color.opacity(0.2), lineWidth: 1)
            )
            .animation(.easeInOut, value: conversation.transcriptText)
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

          Task {
            await conversation.handlePrimaryAction()
          }
        }) {
          ZStack {
            // Button background
            Circle()
              .fill(.ultraThinMaterial)
              .overlay(
                Circle()
                  .stroke(conversation.state.color, lineWidth: 2)
              )
              .shadow(color: conversation.state.color.opacity(0.3), radius: 10, x: 0, y: 5)
              .frame(width: 80, height: 80)

            // Button icon
            Image(systemName: conversation.state == .idle ? "mic.fill" : "stop.fill")
              .font(.system(size: 30, weight: .medium))
              .foregroundColor(conversation.state.color)

            // Pulsating effect when active
            if conversation.state != .idle {
              Circle()
                .stroke(conversation.state.color.opacity(0.5), lineWidth: 2)
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
      Task {
        await conversation.requestSpeechAuthorization()
      }
    }
    .sheet(isPresented: $showingSettings) {
      SettingsView(ttsManager: ttsManager)
    }
  }
}
