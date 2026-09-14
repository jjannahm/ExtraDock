import SwiftUI

// MARK: - EmptyStateView

/// Drop target for an empty Custom Dock. It only appears while something is
/// being dragged to the dock's screen edge.
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.square.dashed")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("Add to Custom Dock")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Drop apps, files, folders,\nor links here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(width: CustomDockLayout.emptySize.width, height: CustomDockLayout.emptySize.height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Custom Dock is empty. Drop items here to add them.")
    }
}
