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
