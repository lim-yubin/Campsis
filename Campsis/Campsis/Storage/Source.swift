import Foundation
@preconcurrency import GRDB

nonisolated enum SourceType: String, Codable, DatabaseValueConvertible, CaseIterable, Sendable {
    case selectedText = "selected_text"
    case screenshot
    case note
    case voice
    case file
}

nonisolated enum ProcessingStatus: String, Codable, DatabaseValueConvertible, Sendable {
    case pending
    case processing
    case completed
    case failed
}

nonisolated struct Source: Codable, Sendable, Identifiable {
    var id: String
    var type: SourceType
    var content: String?
    var screenshotPath: String?
    var filePath: String?
    var audioPath: String?
    var ocrText: String?
    var transcript: String?
    var userNote: String?
    var application: String?
    var windowTitle: String?
    var url: String?
    var capturedAt: Date
    var createdAt: Date
    var processingStatus: ProcessingStatus
    var summary: String?
    var topics: String?
    var processingAttempts: Int

    init(
        type: SourceType,
        content: String? = nil,
        screenshotPath: String? = nil,
        filePath: String? = nil,
        audioPath: String? = nil,
        ocrText: String? = nil,
        transcript: String? = nil,
        userNote: String? = nil,
        application: String? = nil,
        windowTitle: String? = nil,
        url: String? = nil
    ) {
        self.id = UUID().uuidString
        self.type = type
        self.content = content
        self.screenshotPath = screenshotPath
        self.filePath = filePath
        self.audioPath = audioPath
        self.ocrText = ocrText
        self.transcript = transcript
        self.userNote = userNote
        self.application = application
        self.windowTitle = windowTitle
        self.url = url
        self.capturedAt = Date()
        self.createdAt = Date()
        self.processingStatus = .pending
        self.summary = nil
        self.topics = nil
        self.processingAttempts = 0
    }
}

nonisolated extension Source: FetchableRecord, PersistableRecord {
    static let databaseTableName = "source"

    enum Columns: String, ColumnExpression {
        case id, type, content
        case screenshotPath = "screenshot_path"
        case filePath = "file_path"
        case audioPath = "audio_path"
        case ocrText = "ocr_text"
        case transcript
        case userNote = "user_note"
        case application
        case windowTitle = "window_title"
        case url
        case capturedAt = "captured_at"
        case createdAt = "created_at"
        case processingStatus = "processing_status"
        case summary, topics
        case processingAttempts = "processing_attempts"
    }

    enum CodingKeys: String, CodingKey {
        case id, type, content
        case screenshotPath = "screenshot_path"
        case filePath = "file_path"
        case audioPath = "audio_path"
        case ocrText = "ocr_text"
        case transcript
        case userNote = "user_note"
        case application
        case windowTitle = "window_title"
        case url
        case capturedAt = "captured_at"
        case createdAt = "created_at"
        case processingStatus = "processing_status"
        case summary, topics
        case processingAttempts = "processing_attempts"
    }
}
