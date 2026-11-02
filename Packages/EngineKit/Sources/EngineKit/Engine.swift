import Foundation
import JobCore

public protocol Engine: Sendable {
    var id: String { get }
    func canHandle(_ job: Job) -> Bool
    func run(_ job: Job, progress: @Sendable @escaping (Double) -> Void) async throws -> [URL]
}

public enum EngineError: LocalizedError, Sendable {
    case unsupported(String)
    case corruptInput(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupported(let detail):
            return "This build can’t do that yet: \(detail)"
        case .corruptInput(let name):
            return "\(name) looks damaged or isn’t a file this tool understands."
        case .writeFailed(let detail):
            return "Couldn’t save the result: \(detail)"
        }
    }
}
