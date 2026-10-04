//
//  ContentView.swift
//  Duophonic
//
//  Created by Juri Beforth on 01.12.25.
//

import SwiftUI

/// The menu bar window: a header and two plates on the window's Liquid Glass.
/// It draws no background of its own so the window's Liquid Glass shows through.
struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MenuMetrics.sectionSpacing) {
            MainView()
            MenuActionsView()
        }
        .padding(MenuMetrics.windowInset)
    }
}

#if DEBUG
    /// A colorful desktop that darkens in Dark Mode, like the system wallpapers.
    private struct PreviewDesktop: View {
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            LinearGradient(
                colors: [.orange, .pink, .indigo, .teal],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .overlay(.black.opacity(colorScheme == .dark ? 0.6 : 0))
        }
    }

    extension View {
        /// Stands in for the menu bar window in previews: Liquid Glass over a desktop,
        /// so the transparency of the plates can be judged.
        func previewOnWindowGlass() -> some View {
            frame(width: MenuMetrics.windowWidth)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(32)
                .background { PreviewDesktop() }
        }
    }

    #Preview("Off") {
        ContentView()
            .previewOnWindowGlass()
            .environmentObject(AudioAggregateManager.preview)
            .environmentObject(LaunchAtLogin())
    }

    #Preview("Sharing") {
        let manager = AudioAggregateManager.preview
        manager.setEnabled(true)
        return ContentView()
            .previewOnWindowGlass()
            .environmentObject(manager)
            .environmentObject(LaunchAtLogin())
    }
#endif
