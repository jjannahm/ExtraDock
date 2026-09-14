import SwiftUI

// MARK: - DockGridView

struct DockGridView: View {
    @EnvironmentObject var dockViewModel: DockViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: settingsViewModel.iconSpacing) {
                ForEach(dockViewModel.items) { item in
                    DockIconCell(item: item)
                        .environmentObject(dockViewModel)
                        .environmentObject(settingsViewModel)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}
