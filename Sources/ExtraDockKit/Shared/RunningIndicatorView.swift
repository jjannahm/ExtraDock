import SwiftUI

// MARK: - RunningIndicatorView

/// Dot shown next to apps that are running. Callers toggle its opacity rather
/// than removing it so icons don't shift when an app launches or quits.
struct RunningIndicatorView: View {
    var size: CGFloat = 5

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .shadow(color: .white.opacity(0.8), radius: 3)
            .accessibilityHidden(true)
    }
}
