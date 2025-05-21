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
    @State private var downloadProgress: Double = 0.0
    @State private var buttonScale: CGFloat = 1.0
    @Binding var hasCompletedOnboarding: Bool
    @Environment(OnDeviceProcessor.self) var processor
    @Environment(\.colorScheme) private var colorScheme

    // Colors based on state
    private var primaryColor: Color { isModelDownloaded ? .green : .blue }
    private var secondaryColor: Color { primaryColor.opacity(0.2) }
    private var tertiaryColor: Color { primaryColor.opacity(0.1) }

    // Background gradient similar to MainView
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                colorScheme == .dark ? Color.black : Color.white,
                colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8),
                tertiaryColor
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
                            AnimatedProgressView(progress: downloadProgress, color: primaryColor)
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

                // Continue button
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

                    // Haptic feedback
#if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
#endif
                }) {
                    ZStack {
                        // Button background
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(primaryColor, lineWidth: 2)
                            )
                            .shadow(color: primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                            .frame(width: 80, height: 80)

                        // Button icon
                        Image(systemName: "arrow.right")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(primaryColor)

                        // Pulsating effect when ready
                        if isModelDownloaded {
                            Circle()
                                .stroke(primaryColor.opacity(0.5), lineWidth: 2)
                                .frame(width: 90, height: 90)
                                .scaleEffect(buttonScale)
                        }
                    }
                    .scaleEffect(buttonScale)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!isModelDownloaded)
                .opacity(isModelDownloaded ? 1 : 0.6)
                .padding(.bottom, 60)
            }
            .padding(.horizontal)
        }
        .task {
            while !isModelDownloaded { // Keep updating progress until download is complete
                if let percentStr = processor.modelInfo.split(separator: ":").last?.split(separator: "%").first,
                   let percent = Double(percentStr.trimmingCharacters(in: .whitespaces)) {
                    downloadProgress = percent / 100.0
                }

                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    // Handle cancellation or other errors if necessary
                    break
                }
            }
        }
        .task {
            do {
                _ = try await processor.loadModel()
                withAnimation(.spring()) {
                    isModelDownloaded = true
                }
            } catch {
                print("Error loading model: \(error)")
            }
        }
    }
}
