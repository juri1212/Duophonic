//
//  ContentView.swift
//  Duophonic
//
//  Created by Juri Beforth on 01.12.25.
//

import SwiftUI

/// The menu bar window, laid out like the system's Control Center modules.
/// It draws no background of its own so the window's Liquid Glass shows through.
struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MainView()
            MenuSeparator()
            MenuActionsView()
        }
        .padding(MenuMetrics.windowInset)
    }
}

#if DEBUG
    #Preview("Off") {
        ContentView()
            .frame(width: 300)
            .environmentObject(AudioAggregateManager.preview)
            .environmentObject(LaunchAtLogin())
    }

    #Preview("Sharing") {
        let manager = AudioAggregateManager.preview
        manager.setEnabled(true)
        return ContentView()
            .frame(width: 300)
            .environmentObject(manager)
            .environmentObject(LaunchAtLogin())
    }
#endif
