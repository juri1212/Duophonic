//
//  Duophonic.swift
//  Duophonic
//
//  Created by Juri Beforth on 01.12.25.
//

import AppKit
import SwiftUI
import os

private let logger = Logger(subsystem: "com.juri1212.Duophonic", category: "App")

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Owned by the app rather than a view, so the aggregate's lifetime matches the process.
    let audioManager = AudioAggregateManager(hardware: CoreAudioHardware())
    let launchAtLogin = LaunchAtLogin()
    private var signalSources: [any DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests are hosted by the app; keep them away from the real audio setup.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        guard !isAnotherInstanceRunning else {
            logger.info("Duophonic is already running; quitting")
            NSApp.terminate(nil)
            return
        }
        quitGracefullyOnSignals()
        audioManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        audioManager.shutdown()
    }

    private var isAnotherInstanceRunning: Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0 != .current }
    }

    /// `kill`, `killall` and logout scripts send signals that would otherwise skip cleanup and
    /// leave the system output pointing at the aggregate.
    private func quitGracefullyOnSignals() {
        for signalNumber in [SIGTERM, SIGINT, SIGHUP] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler {
                MainActor.assumeIsolated { NSApp.terminate(nil) }
            }
            source.resume()
            signalSources.append(source)
        }
    }
}

@main
struct Duophonic: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Use a custom image asset for the menu bar icon. Create an image set named
        // "StatusBarIcon" inside Assets.xcassets (preferably a template/monochrome 18pt).
        // Note: the special AppIcon app icon set (AppIcon.appiconset) isn't directly
        // loadable by `Image("...")`, so create a separate image set for the status bar.
        MenuBarExtra {
            ContentView()
                .frame(width: 300)
                .environmentObject(appDelegate.audioManager)
                .environmentObject(appDelegate.launchAtLogin)
        } label: {
            Image("StatusBarIcon")
                .renderingMode(.template)  // allow system tinting for light/dark
        }
        .menuBarExtraStyle(.window)
    }
}
