import SwiftUI

// Animated progress indicator
struct AnimatedProgressView: View {
  let progress: Double
  let color: Color
  @State private var rotation: Double = 0

  var body: some View {
    ZStack {
      // Track
      Circle()
        .stroke(color.opacity(0.2), lineWidth: 6)
        .frame(width: 80, height: 80)

      // Progress
      Circle()
        .trim(from: 0, to: CGFloat(min(progress, 1.0)))
        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
        .frame(width: 80, height: 80)
        .rotationEffect(.degrees(-90))
        .animation(.easeOut, value: progress)

      // Spinning dot
      Circle()
        .fill(color)
        .frame(width: 12, height: 12)
        .offset(y: -40)
        .rotationEffect(.degrees(rotation))
        .animation(
          Animation.linear(duration: 2)
            .repeatForever(autoreverses: false),
          value: rotation
        )
        .onAppear {
          rotation = 360
        }
    }
  }
}

struct OnboardingView: View {
  @State private var isModelDownloaded = false
  @State private var isKokoroModelDownloaded = false
  @State private var buttonScale: CGFloat = 1.0
  @State private var kokoroButtonScale: CGFloat = 1.0
  @Binding var hasCompletedOnboarding: Bool
  @Environment(OnDeviceProcessor.self) var processor
  @Environment(\.colorScheme) private var colorScheme

  // Text-to-speech manager
  @State private var ttsManager = TTSManager()

  // Colors based on state
  private var primaryColor: Color { isModelDownloaded ? .green : .blue }
  private var secondaryColor: Color { primaryColor.opacity(0.2) }
  private var tertiaryColor: Color { primaryColor.opacity(0.1) }

  // Kokoro download function
  private func downloadKokoroModel() {
    // Initialize the model by triggering a small text to convert
    // This will make the model download its resources
    let testText = "Hello"
    // Use Kokoro engine for initial download
    ttsManager.currentEngine = .kokoro
    ttsManager.say(testText, speed: 1.0)
    ttsManager.stopPlayback()  // Stop playback immediately

    // Mark as downloaded after a short delay
    // This is a simplification - in a real app we would monitor download progress
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      withAnimation(.spring()) {
        isKokoroModelDownloaded = true
      }
    }
  }

  // Background gradient similar to MainView
  private var backgroundGradient: LinearGradient {
    LinearGradient(
      gradient: Gradient(colors: [
        colorScheme == .dark ? Color.black : Color.white,
        colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8),
        tertiaryColor,
      ]),
      startPoint: .top,
      endPoint: .bottom
    )
  }

  var body: some View {
    ZStack {
      // Background gradient
      backgroundGradient
        .ignoresSafeArea()

      VStack(spacing: 40) {
        Spacer()

        // App icon with pulsating effect
        ZStack {
          // Pulsating background
          if !isModelDownloaded {
            PulsatingCircle(
              color: primaryColor,
              startRadius: 100,
              endRadius: 130
            )
          }

          // Icon background
          Circle()
            .fill(secondaryColor)
            .frame(width: 120, height: 120)

          // Icon border
          Circle()
            .stroke(primaryColor.opacity(0.3), lineWidth: 1)
            .frame(width: 120, height: 120)

          // Icon
          Image(systemName: isModelDownloaded ? "waveform.circle.fill" : "waveform.circle")
            .font(.system(size: 60, weight: .light))
            .foregroundColor(primaryColor)
        }
        .padding(.bottom, 20)

        // Welcome text
        VStack(spacing: 8) {
          Text("Welcome to Ichi")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(primaryColor)

          Text("Your Private, On-Device Conversational AI")
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
        }

        Spacer()

        // Download status area
        VStack(spacing: 20) {
          ZStack {
            if isModelDownloaded {
              // Success icon
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)
                .transition(.scale.combined(with: .opacity))
            } else {
              // Progress indicator
              AnimatedProgressView(progress: 0.5, color: primaryColor)
                .transition(.opacity)
            }
          }
          .frame(height: 80)
          .animation(.spring(response: 0.6), value: isModelDownloaded)

          // Status text
          VStack(spacing: 8) {
            Text(isModelDownloaded ? "Ready to start!" : "Downloading model...")
              .font(.system(size: 18, weight: .semibold, design: .rounded))
              .foregroundColor(primaryColor)

            Text(processor.modelInfo)
              .font(.system(size: 14, design: .rounded))
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .frame(maxWidth: 300)
              .animation(.easeInOut, value: processor.modelInfo)
          }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .stroke(primaryColor.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)

        Spacer()

        // Kokoro download button (appears after main model is downloaded)
        if isModelDownloaded && !isKokoroModelDownloaded {
          VStack(spacing: 10) {
            Text("Download Kokoro TTS Model")
              .font(.system(size: 16, weight: .medium, design: .rounded))
              .foregroundColor(primaryColor)

            Button(action: {
              // Button press animation
              withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                kokoroButtonScale = 0.9
              }

              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                  kokoroButtonScale = 1.0
                }
                downloadKokoroModel()
              }
            }) {
              ZStack {
                RoundedRectangle(cornerRadius: 12)
                  .fill(.ultraThinMaterial)
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(primaryColor, lineWidth: 2)
                  )
                  .frame(height: 50)

                Text("Download TTS")
                  .font(.system(size: 16, weight: .semibold, design: .rounded))
                  .foregroundColor(primaryColor)
              }
              .scaleEffect(kokoroButtonScale)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 40)
          }
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .animation(.spring(response: 0.6), value: isModelDownloaded)
        }

        // Continue button (appears after both models are downloaded)
        if isModelDownloaded && isKokoroModelDownloaded {
          Button(action: {
            // Button press animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
              buttonScale = 0.9
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              withAnimation {
                buttonScale = 1.0
                hasCompletedOnboarding = true
              }
            }
          }) {
            ZStack {
              RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                  RoundedRectangle(cornerRadius: 16)
                    .stroke(primaryColor, lineWidth: 2)
                )
                .frame(height: 56)
                .shadow(color: primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)

              HStack(spacing: 12) {
                Image(systemName: "arrow.right.circle.fill")
                  .font(.system(size: 20))
                  .foregroundColor(primaryColor)

                Text("Start Conversation")
                  .font(.system(size: 18, weight: .semibold, design: .rounded))
                  .foregroundColor(primaryColor)
              }
            }
            .scaleEffect(buttonScale)
          }
          .buttonStyle(PlainButtonStyle())
          .padding(.horizontal, 40)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .animation(.spring(response: 0.6), value: isKokoroModelDownloaded)
        }

        Spacer()
      }
      .padding(.horizontal)
    }
    .onAppear {
      // Simulate model download
      Task {
        _ = try? await processor.loadModel()
        withAnimation(.spring()) {
          isModelDownloaded = true
        }
      }
    }
  }
}
