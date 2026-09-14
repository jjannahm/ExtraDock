import SwiftUI

// MARK: - EmptyStateView

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("Drop apps here")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Drag apps, files, folders, or links\nhere to add them.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(width: CustomDockLayout.emptySize.width, height: CustomDockLayout.emptySize.height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Custom Dock is empty. Drag apps here to add them.")
    }
}
