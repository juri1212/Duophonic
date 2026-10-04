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
    #Preview("Off") {
        ContentView()
            .frame(width: MenuMetrics.windowWidth)
            .environmentObject(AudioAggregateManager.preview)
            .environmentObject(LaunchAtLogin())
    }

    #Preview("Sharing") {
        let manager = AudioAggregateManager.preview
        manager.setEnabled(true)
        return ContentView()
            .frame(width: MenuMetrics.windowWidth)
            .environmentObject(manager)
            .environmentObject(LaunchAtLogin())
    }
#endif
