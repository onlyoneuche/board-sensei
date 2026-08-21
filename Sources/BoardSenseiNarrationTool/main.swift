import Foundation
import MusicCore

private struct Options {
    var voice = "alba"
    var voiceLicense = "CC-BY-4.0"
    var language = "english"
    var decodeSteps = 5
    var lessonID: String?
    var force = false
    var dryRun = false
    var check = false
    var voiceWasOverridden = false
    var licenseWasOverridden = false
}

private enum ToolError: LocalizedError {
    case usage(String)
    case invalidManifest(String)
    case staleAssets([String])
    case processFailed(String, Int32, String)

    var errorDescription: String? {
        switch self {
        case let .usage(message): message
        case let .invalidManifest(message): "Invalid narration manifest: \(message)"
        case let .staleAssets(ids): "Missing or stale narration assets: \(ids.joined(separator: ", "))"
        case let .processFailed(tool, status, message):
            "\(tool) failed with exit status \(status): \(message)"
        }
    }
}

@main
private struct BoardSenseiNarrationTool {
    static func main() {
        do {
            try runTool()
        } catch {
            let message = "error: \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }

    private static func runTool() throws {
        let options = try parseOptions()
        let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/BoardSenseiApp/Resources/Narration", isDirectory: true)
        let manifestURL = outputDirectory.appendingPathComponent("manifest.json")

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        var manifest = try loadManifest(at: manifestURL)
        guard manifest.schemaVersion == NarrationManifest.currentSchemaVersion else {
            throw ToolError.invalidManifest("unsupported schema version \(manifest.schemaVersion)")
        }

        let allLessons = JazzCourseCatalog.course.stages.flatMap(\.modules).flatMap(\.lessons)
        let selectedLessons: [PracticeLesson]
        if let lessonID = options.lessonID {
            guard let lesson = allLessons.first(where: { $0.id == lessonID }) else {
                throw ToolError.usage("Unknown lesson ID: \(lessonID)")
            }
            selectedLessons = [lesson]
        } else {
            selectedLessons = allLessons
        }

        if options.check {
            let stale = selectedLessons.compactMap { lesson -> String? in
                isCurrent(lesson, manifest: manifest, outputDirectory: outputDirectory) ? nil : lesson.id
            }
            guard stale.isEmpty else { throw ToolError.staleAssets(stale) }
            print("Narration assets are current for \(selectedLessons.count) lesson(s).")
            return
        }

        var generatedCount = 0
        for (index, lesson) in selectedLessons.enumerated() {
            let progress = "[\(index + 1)/\(selectedLessons.count)]"
            if !options.force && isCurrent(lesson, manifest: manifest, outputDirectory: outputDirectory) {
                print("\(progress) current   \(lesson.id)")
                continue
            }

            let filename = "\(lesson.id)-\(lesson.narrationContentHash.prefix(12)).wav"
            if options.dryRun {
                print("\(progress) generate  \(lesson.id) -> \(filename) (\(lesson.narrationScript.count) characters)")
                continue
            }

            let destination = outputDirectory.appendingPathComponent(filename)
            print("\(progress) generate  \(lesson.id) — starting Pocket TTS (the first run may download model files)")
            try generateAudio(
                text: lesson.narrationScript,
                destination: destination,
                options: options
            )
            manifest.lessons[lesson.id] = NarrationAsset(
                contentHash: lesson.narrationContentHash,
                file: filename,
                voiceID: options.voice,
                voiceLicense: options.voiceLicense,
                model: "pocket-tts:\(options.language):lsd=\(options.decodeSteps)",
                generatedAt: ISO8601DateFormatter().string(from: Date())
            )
            try writeManifest(manifest, to: manifestURL)
            generatedCount += 1
            print("\(progress) saved     \(destination.path)")
        }

        guard !options.dryRun else { return }

        let validIDs = Set(allLessons.map(\.id))
        manifest.lessons = manifest.lessons.filter { validIDs.contains($0.key) }
        try writeManifest(manifest, to: manifestURL)
        print("Updated manifest. Generated \(generatedCount) lesson(s).")
    }

    private static func parseOptions() throws -> Options {
        var options = Options()
        var index = 1
        let arguments = CommandLine.arguments

        while index < arguments.count {
            switch arguments[index] {
            case "--voice":
                index += 1
                guard index < arguments.count else { throw ToolError.usage("--voice requires a value") }
                options.voice = arguments[index]
                options.voiceWasOverridden = true
            case "--voice-license":
                index += 1
                guard index < arguments.count else {
                    throw ToolError.usage("--voice-license requires a value")
                }
                options.voiceLicense = arguments[index]
                options.licenseWasOverridden = true
            case "--language":
                index += 1
                guard index < arguments.count else { throw ToolError.usage("--language requires a value") }
                options.language = arguments[index]
            case "--decode-steps":
                index += 1
                guard index < arguments.count, let steps = Int(arguments[index]), (1...10).contains(steps) else {
                    throw ToolError.usage("--decode-steps requires an integer from 1 through 10")
                }
                options.decodeSteps = steps
            case "--lesson":
                index += 1
                guard index < arguments.count else { throw ToolError.usage("--lesson requires an ID") }
                options.lessonID = arguments[index]
            case "--force": options.force = true
            case "--dry-run": options.dryRun = true
            case "--check": options.check = true
            case "--help", "-h":
                printUsage()
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw ToolError.usage("Unknown argument: \(arguments[index]). Use --help for options.")
            }
            index += 1
        }

        if options.voiceWasOverridden && !options.licenseWasOverridden {
            throw ToolError.usage(
                "A custom --voice also requires --voice-license so redistribution rights are recorded."
            )
        }
        return options
    }

    private static func printUsage() {
        print("""
        Usage: swift run BoardSenseiNarrationTool [options]

          --dry-run              Show which lessons need generation without running Pocket TTS
          --check                Fail when a selected narration asset is missing or stale
          --lesson ID            Process one lesson instead of the complete catalog
          --voice VOICE          Pocket TTS voice name, file, or URL (default: alba)
          --voice-license SPDX   Required with --voice; stored in the manifest
          --language LANGUAGE    Pocket TTS language configuration (default: english)
          --decode-steps 1...10  Quality/speed tradeoff (default: 5)
          --force                Regenerate even when the content hash is current

        Generation is local and free. It requires uvx. The first run
        downloads Pocket TTS model data. The default Alba voice is CC-BY-4.0 licensed.
        """)
    }

    private static func loadManifest(at url: URL) throws -> NarrationManifest {
        guard FileManager.default.fileExists(atPath: url.path) else { return NarrationManifest() }
        do {
            return try JSONDecoder().decode(NarrationManifest.self, from: Data(contentsOf: url))
        } catch {
            throw ToolError.invalidManifest(error.localizedDescription)
        }
    }

    private static func writeManifest(_ manifest: NarrationManifest, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(manifest)
        data.append(0x0A)
        try data.write(to: url, options: .atomic)
    }

    private static func isCurrent(
        _ lesson: PracticeLesson,
        manifest: NarrationManifest,
        outputDirectory: URL
    ) -> Bool {
        guard let asset = manifest.lessons[lesson.id],
              asset.contentHash == lesson.narrationContentHash,
              !asset.voiceID.isEmpty,
              asset.voiceLicense?.isEmpty == false,
              !asset.model.isEmpty else {
            return false
        }
        return FileManager.default.fileExists(
            atPath: outputDirectory.appendingPathComponent(asset.file).path
        )
    }

    private static func generateAudio(text: String, destination: URL, options: Options) throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("board-sensei-narration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let wav = temporaryDirectory.appendingPathComponent("narration.wav")
        print("staging   \(wav.path) (temporary; removed after the final asset is saved)")
        try run(
            executable: "/usr/bin/env",
            arguments: [
                "uvx", "pocket-tts", "generate",
                "--text", text,
                "--voice", options.voice,
                "--output-path", wav.path,
                "--language", options.language,
                "--lsd-decode-steps", String(options.decodeSteps),
            ],
            name: "Pocket TTS"
        )
        let data = try Data(contentsOf: wav)
        try data.write(to: destination, options: .atomic)
    }

    private static func run(executable: String, arguments: [String], name: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        let startedAt = Date()
        var nextHeartbeat = 10
        while process.isRunning {
            Thread.sleep(forTimeInterval: 1)
            let elapsed = Int(Date().timeIntervalSince(startedAt))
            if elapsed >= nextHeartbeat {
                print("working   \(name) is still running — \(elapsed)s elapsed")
                nextHeartbeat += 10
            }
        }
        process.waitUntilExit()

        guard process.terminationStatus == EXIT_SUCCESS else {
            throw ToolError.processFailed(
                name,
                process.terminationStatus,
                "See the command output above for details."
            )
        }
    }
}
