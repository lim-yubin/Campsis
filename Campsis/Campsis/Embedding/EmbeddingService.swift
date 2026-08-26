import CoreML
import Foundation
import Tokenizers

actor EmbeddingService {
    static let modelName = "bge-m3"
    static let embeddingVersion = "v1"
    static let dimensions = 1024
    private static let maxSeqLen = 512

    private var model: MLModel?
    private var tokenizer: Tokenizer?
    private var isLoaded = false

    private struct UnsafeSendableModel: @unchecked Sendable {
        let model: MLModel
    }

    private let modelDirectory: URL

    init(modelDirectory: URL? = nil) {
        self.modelDirectory = modelDirectory ?? Self.defaultModelDirectory()
    }

    private static func defaultModelDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Campsis/Models", isDirectory: true)
    }

    var isAvailable: Bool {
        isLoaded
    }

    func loadIfNeeded() async throws {
        guard !isLoaded else { return }

        let mlpackagePath = modelDirectory.appendingPathComponent("bge-m3-seq512-fp16.mlpackage")
        let compiledPath = modelDirectory.appendingPathComponent("bge-m3-seq512-fp16.mlmodelc")

        guard FileManager.default.fileExists(atPath: mlpackagePath.path) ||
              FileManager.default.fileExists(atPath: compiledPath.path) else {
            throw EmbeddingError.modelNotFound(mlpackagePath.path)
        }

        if FileManager.default.fileExists(atPath: compiledPath.path) {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            model = try MLModel(contentsOf: compiledPath, configuration: config)
        } else {
            NSLog("[EmbeddingService] Compiling model (one-time)...")
            let compiled = try await MLModel.compileModel(at: mlpackagePath)
            if FileManager.default.fileExists(atPath: compiledPath.path) {
                try FileManager.default.removeItem(at: compiledPath)
            }
            try FileManager.default.copyItem(at: compiled, to: compiledPath)
            let config = MLModelConfiguration()
            config.computeUnits = .all
            model = try MLModel(contentsOf: compiledPath, configuration: config)
        }

        tokenizer = try await AutoTokenizer.from(modelFolder: modelDirectory)

        isLoaded = true
        NSLog("[EmbeddingService] Model loaded successfully")
    }

    func embed(_ text: String) async throws -> [Float] {
        guard let model, let tokenizer else {
            throw EmbeddingError.notLoaded
        }

        let encoded = tokenizer.encode(text: text)
        let tokenCount = min(encoded.count, Self.maxSeqLen)

        let idsArray = try MLMultiArray(shape: [1, NSNumber(value: Self.maxSeqLen)], dataType: .int32)
        let maskArray = try MLMultiArray(shape: [1, NSNumber(value: Self.maxSeqLen)], dataType: .int32)

        for i in 0..<Self.maxSeqLen {
            if i < tokenCount {
                idsArray[[0, NSNumber(value: i)]] = NSNumber(value: Int32(encoded[i]))
                maskArray[[0, NSNumber(value: i)]] = NSNumber(value: Int32(1))
            } else {
                idsArray[[0, NSNumber(value: i)]] = NSNumber(value: Int32(0))
                maskArray[[0, NSNumber(value: i)]] = NSNumber(value: Int32(0))
            }
        }

        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: idsArray),
            "attention_mask": MLFeatureValue(multiArray: maskArray),
        ])

        let wrapper = UnsafeSendableModel(model: model)
        let output = try await wrapper.model.prediction(from: inputFeatures)

        guard let embeddingValue = output.featureValue(for: "embedding"),
              let embeddingArray = embeddingValue.multiArrayValue else {
            throw EmbeddingError.outputMissing
        }

        var vector = [Float](repeating: 0, count: Self.dimensions)

        switch embeddingArray.dataType {
        case .float16:
            let ptr = embeddingArray.dataPointer.bindMemory(to: Float16.self, capacity: Self.dimensions)
            for i in 0..<Self.dimensions {
                vector[i] = Float(ptr[i])
            }
        case .float32:
            let ptr = embeddingArray.dataPointer.bindMemory(to: Float.self, capacity: Self.dimensions)
            for i in 0..<Self.dimensions {
                vector[i] = ptr[i]
            }
        default:
            for i in 0..<Self.dimensions {
                vector[i] = embeddingArray[[0, NSNumber(value: i)]].floatValue
            }
        }

        return vector
    }
}

enum EmbeddingError: Error, Sendable {
    case modelNotFound(String)
    case tokenizerNotFound(String)
    case notLoaded
    case outputMissing
}
