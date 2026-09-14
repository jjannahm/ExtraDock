import SwiftUI

// MARK: - RunningIndicatorView

struct RunningIndicatorView: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 5, height: 5)
            .shadow(color: .white.opacity(0.8), radius: 3)
            .accessibilityHidden(true)
    }
}

#Preview {
    RunningIndicatorView()
        .padding()
}
