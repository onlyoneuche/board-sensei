import Foundation
import MusicCore

private struct Options {
    var model = "eleven_v3"
    var lessonID: String?
    var force = false
    var dryRun = false
    var check = false
}

private enum ToolError: LocalizedError {
    case usage(String)
    case missingEnvironment(String)
    case invalidManifest(String)
    case staleAssets([String])
    case requestFailed(Int, String)
    case scriptTooLong(String, Int)

    var errorDescription: String? {
        switch self {
        case let .usage(message): message
        case let .missingEnvironment(name): "Missing required environment variable: \(name)"
        case let .invalidManifest(message): "Invalid narration manifest: \(message)"
        case let .staleAssets(ids): "Missing or stale narration assets: \(ids.joined(separator: ", "))"
        case let .requestFailed(status, message): "ElevenLabs request failed (HTTP \(status)): \(message)"
        case let .scriptTooLong(id, count): "Narration for \(id) is \(count) characters; split or shorten it before generation."
        }
    }
}

@main
private struct BoardSenseiNarrationTool {
    private static let outputFormat = "mp3_44100_128"

    static func main() async throws {
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

        let environment = ProcessInfo.processInfo.environment
        let apiKey = environment["ELEVENLABS_API_KEY"]
        let voiceID = environment["ELEVENLABS_VOICE_ID"]
        var generatedCount = 0

        for lesson in selectedLessons {
            if !options.force && isCurrent(lesson, manifest: manifest, outputDirectory: outputDirectory) {
                print("current   \(lesson.id)")
                continue
            }

            let filename = "\(lesson.id)-\(lesson.narrationContentHash.prefix(12)).mp3"
            if options.dryRun {
                print("generate  \(lesson.id) -> \(filename) (\(lesson.narrationScript.count) characters)")
                continue
            }

            guard let apiKey, !apiKey.isEmpty else {
                throw ToolError.missingEnvironment("ELEVENLABS_API_KEY")
            }
            guard let voiceID, !voiceID.isEmpty else {
                throw ToolError.missingEnvironment("ELEVENLABS_VOICE_ID")
            }
            guard lesson.narrationScript.count <= 3_000 else {
                throw ToolError.scriptTooLong(lesson.id, lesson.narrationScript.count)
            }

            print("generate  \(lesson.id)")
            let audio = try await generateAudio(
                text: lesson.narrationScript,
                voiceID: voiceID,
                model: options.model,
                apiKey: apiKey
            )
            try audio.write(to: outputDirectory.appendingPathComponent(filename), options: .atomic)
            manifest.lessons[lesson.id] = NarrationAsset(
                contentHash: lesson.narrationContentHash,
                file: filename,
                voiceID: voiceID,
                model: options.model,
                generatedAt: ISO8601DateFormatter().string(from: Date())
            )
            generatedCount += 1
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
            case "--model":
                index += 1
                guard index < arguments.count else { throw ToolError.usage("--model requires a value") }
                options.model = arguments[index]
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
        return options
    }

    private static func printUsage() {
        print("""
        Usage: swift run BoardSenseiNarrationTool [options]

          --dry-run          Show which lessons need generation without calling the API
          --check            Fail when a selected narration asset is missing or stale
          --lesson ID        Process one lesson instead of the complete catalog
          --model MODEL      ElevenLabs model ID (default: eleven_v3)
          --force            Regenerate even when the content hash is current

        Generation requires ELEVENLABS_API_KEY and ELEVENLABS_VOICE_ID.
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
              asset.contentHash == lesson.narrationContentHash else {
            return false
        }
        return FileManager.default.fileExists(
            atPath: outputDirectory.appendingPathComponent(asset.file).path
        )
    }

    private static func generateAudio(
        text: String,
        voiceID: String,
        model: String,
        apiKey: String
    ) async throws -> Data {
        var endpoint = URL(string: "https://api.elevenlabs.io/v1/text-to-speech")!
            .appendingPathComponent(voiceID)
        endpoint.append(queryItems: [URLQueryItem(name: "output_format", value: outputFormat)])

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "model_id": model,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = String(data: data, encoding: .utf8) ?? "No response body"
            throw ToolError.requestFailed(status, message)
        }
        return data
    }
}
