//
//  PulsatingCircle.swift
//  Ichi
//
//  Created by Rudrank Riyam on 5/21/25.
//

import SwiftUI

struct PulsatingCircle: View {
    @State private var pulsate = false
    let color: Color
    let startRadius: CGFloat
    let endRadius: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: pulsate ? endRadius : startRadius,
                   height: pulsate ? endRadius : startRadius)
            .opacity(pulsate ? 0 : 0.5)
            .animation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: false),
                value: pulsate
            )
            .onAppear {
                pulsate = true
            }
    }
}

#Preview {
    PulsatingCircle(color: .red, startRadius: 20, endRadius: 50)
}
