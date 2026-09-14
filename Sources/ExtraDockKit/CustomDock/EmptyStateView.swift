import SwiftUI

// MARK: - EmptyStateView

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.dashed")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Drop apps here")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Drag applications, files, or URLs\nfrom Finder to add them.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(minWidth: 200, minHeight: 100)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dock is empty. Drag apps here to add them.")
    }
}

#Preview {
    EmptyStateView()
}
