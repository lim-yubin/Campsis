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

/// MD(진실원) 생성 상태. summary/topics 처리(ProcessingStatus)와 독립적으로 관리한다 (D39, D40).
nonisolated enum MarkdownStatus: String, Codable, DatabaseValueConvertible, Sendable {
    case pending      // 아직 생성 안 됨 (온라인 + Luna 구성 시 백그라운드 생성)
    case processing
    case completed
    case failed
}

nonisolated struct Source: Codable, Sendable, Identifiable, Hashable {
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
    var markdownPath: String?
    var markdownStatus: MarkdownStatus
    var markdownUpdatedAt: Date?

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
        self.markdownPath = nil
        self.markdownStatus = .pending
        self.markdownUpdatedAt = nil
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
        case markdownPath = "markdown_path"
        case markdownStatus = "markdown_status"
        case markdownUpdatedAt = "markdown_updated_at"
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
        case markdownPath = "markdown_path"
        case markdownStatus = "markdown_status"
        case markdownUpdatedAt = "markdown_updated_at"
    }
}
