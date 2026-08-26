import Darwin
import Foundation
import os

/// Crash-oriented diagnostics for UI/audio integration points.
///
/// This intentionally avoids the MIDI receive and audio render callbacks. Each
/// line is written directly to stderr and to a per-process file so the final
/// event survives a hard crash. Debug builds enable tracing by default; set
/// `BOARD_SENSEI_DIAGNOSTICS=0` to silence it.
enum BoardSenseiDiagnostics {
    private static let logger = Logger(
        subsystem: "com.wandikorindustries.BoardSensei",
        category: "runtime"
    )
    private static let processID = getpid()
    private static let launchUptime = ProcessInfo.processInfo.systemUptime
    private static let logPath = "/tmp/board-sensei-\(processID).log"

    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["BOARD_SENSEI_DIAGNOSTICS"] != "0"
        #else
        ProcessInfo.processInfo.environment["BOARD_SENSEI_DIAGNOSTICS"] == "1"
        #endif
    }

    static var currentLogPath: String { logPath }

    static func trace(
        _ category: String,
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        guard isEnabled else { return }
        let elapsed = max(0, ProcessInfo.processInfo.systemUptime - launchUptime)
        let thread = Thread.isMainThread ? "main" : "background"
        let entry = String(
            format: "[BS-TRACE +%.3fs pid=%d %@] %@ | %@:%u\n",
            elapsed,
            processID,
            thread,
            "\(category): \(message())",
            "\(file)",
            line
        )
        write(entry, to: STDERR_FILENO)
        append(entry, to: logPath)
        logger.notice("\(entry, privacy: .public)")
    }

    private static func write(_ value: String, to descriptor: Int32) {
        value.withCString { pointer in
            _ = Darwin.write(descriptor, pointer, strlen(pointer))
        }
    }

    private static func append(_ value: String, to path: String) {
        let descriptor = Darwin.open(
            path,
            O_WRONLY | O_CREAT | O_APPEND,
            S_IRUSR | S_IWUSR
        )
        guard descriptor >= 0 else { return }
        write(value, to: descriptor)
        Darwin.close(descriptor)
    }
}
