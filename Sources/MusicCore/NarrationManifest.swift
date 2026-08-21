import Foundation

public struct NarrationManifest: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var lessons: [String: NarrationAsset]

    public init(
        schemaVersion: Int = NarrationManifest.currentSchemaVersion,
        lessons: [String: NarrationAsset] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.lessons = lessons
    }
}

public struct NarrationAsset: Codable, Sendable, Equatable {
    public let contentHash: String
    public let file: String
    public let voiceID: String
    public let voiceLicense: String?
    public let model: String
    public let generatedAt: String

    public init(
        contentHash: String,
        file: String,
        voiceID: String,
        voiceLicense: String? = nil,
        model: String,
        generatedAt: String
    ) {
        self.contentHash = contentHash
        self.file = file
        self.voiceID = voiceID
        self.voiceLicense = voiceLicense
        self.model = model
        self.generatedAt = generatedAt
    }
}
