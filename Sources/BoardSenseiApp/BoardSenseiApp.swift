import AppKit
import SwiftUI

@main
struct BoardSenseiApp: App {
    @NSApplicationDelegateAdaptor(BoardSenseiAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 680)
                .task { model.start() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandMenu("Playback") {
                Button("Stop Exercise Playback") {
                    model.stopExercisePreview()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!model.isPracticeMode || !model.isPreviewPlaying)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 620, height: 520)
        }
    }
}

@MainActor
final class BoardSenseiAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.applicationIconImage = BoardSenseiAppIcon.make()
        DispatchQueue.main.async {
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
