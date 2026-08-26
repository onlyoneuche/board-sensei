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
                .task {
                    appDelegate.stopPlaybackAction = {
                        guard model.isPracticeMode, model.isPreviewPlaying else { return false }
                        BoardSenseiDiagnostics.trace("keyboard-action", "Space stopping exercise playback")
                        model.stopExercisePreview()
                        return true
                    }
                    model.start()
                }
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
    private var diagnosticEventMonitor: Any?
    var stopPlaybackAction: (() -> Bool)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        BoardSenseiDiagnostics.trace(
            "lifecycle",
            "applicationDidFinishLaunching; log=\(BoardSenseiDiagnostics.currentLogPath)"
        )
        diagnosticEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseUp, .keyDown]
        ) { event in
            let windowNumber = event.window?.windowNumber ?? -1
            let viewName = event.window?.contentView?.hitTest(event.locationInWindow)
                .map { NSStringFromClass(type(of: $0)) } ?? "none"
            let key = event.type == .keyDown ? " keyCode=\(event.keyCode)" : ""
            BoardSenseiDiagnostics.trace(
                "appkit-event",
                "type=\(event.type.rawValue) window=\(windowNumber) "
                    + "point=(\(Int(event.locationInWindow.x)),\(Int(event.locationInWindow.y))) "
                    + "hit=\(viewName)\(key)"
            )
            if event.type == .keyDown,
               event.keyCode == 49,
               !event.isARepeat,
               event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
               self.stopPlaybackAction?() == true {
                return nil
            }
            return event
        }
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

    func applicationWillTerminate(_ notification: Notification) {
        BoardSenseiDiagnostics.trace("lifecycle", "applicationWillTerminate")
        if let diagnosticEventMonitor {
            NSEvent.removeMonitor(diagnosticEventMonitor)
        }
    }
}
