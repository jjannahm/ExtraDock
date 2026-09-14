import AppKit
import SwiftUI

// MARK: - DockIconCell

struct DockIconCell: View {
    let item: DockItem

    @EnvironmentObject var dockViewModel: DockViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var renameText = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed Properties

    var isRunning: Bool {
        dockViewModel.isRunning(item)
    }

    var iconImage: NSImage {
        dockViewModel.icon(for: item)
    }

    var iconSize: CGFloat {
        let base = settingsViewModel.iconSize
        guard isHovered, settingsViewModel.magnificationEnabled else { return base }
        return base * settingsViewModel.magnificationScale
    }

    var animationDuration: Double {
        reduceMotion ? 0 : 0.15
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: iconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .grayscale(settingsViewModel.useMonochromeIcons ? 1.0 : 0.0)
                .shadow(
                    color: isHovered ? .black.opacity(0.3) : .clear,
                    radius: 4, x: 0, y: 2
                )
                .animation(.easeInOut(duration: animationDuration), value: iconSize)
                .animation(.easeInOut(duration: animationDuration), value: isHovered)

            if settingsViewModel.showLabels {
                Text(item.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }

            if isRunning {
                RunningIndicatorView()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: animationDuration)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            dockViewModel.launchItem(item)
        }
        .contextMenu {
            contextMenuContent
        }
        .sheet(isPresented: $isRenaming) {
            RenameSheet(text: $renameText, isPresented: $isRenaming) { newName in
                dockViewModel.renameItem(item, to: newName)
            }
        }
        .accessibilityLabel("\(item.displayName), \(item.type.rawValue)\(isRunning ? ", running" : "")")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Open") {
            dockViewModel.launchItem(item)
        }

        if item.type != .url {
            Button("Reveal in Finder") {
                dockViewModel.revealInFinder(item)
            }
        }

        Divider()

        Button("Rename…") {
            renameText = item.displayName
            isRenaming = true
        }

        Divider()

        Button("Remove", role: .destructive) {
            dockViewModel.removeItem(item)
        }
    }
}

// MARK: - RenameSheet

struct RenameSheet: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    var onRename: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Item")
                .font(.headline)

            TextField("Name", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    guard !text.isEmpty else { return }
                    onRename(text)
                    isPresented = false
                }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Button("Rename") {
                    onRename(text)
                    isPresented = false
                }
                .keyboardShortcut(.return)
                .disabled(text.isEmpty)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
