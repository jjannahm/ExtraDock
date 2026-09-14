import SwiftUI
import UniformTypeIdentifiers

// MARK: - DockContainerView

struct DockContainerView: View {
    @EnvironmentObject var dockViewModel: DockViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )

            Group {
                if dockViewModel.items.isEmpty {
                    EmptyStateView()
                } else {
                    DockGridView()
                        .environmentObject(dockViewModel)
                        .environmentObject(settingsViewModel)
                }
            }
        }
        .opacity(settingsViewModel.opacity)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        for provider in fileProviders {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    self.dockViewModel.addItemFromURL(url)
                }
            }
        }
        return !fileProviders.isEmpty
    }
}
