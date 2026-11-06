import Foundation
import JobCore
import EngineKit

struct SubtitleCue {
    var start: Int
    var end: Int
    var text: String
}

struct SubtitleEngine: Engine {
    let id = "subtitle.convert"

    func canHandle(_ job: Job) -> Bool {
        guard case .convert(let ext) = job.operation,
              ["srt", "vtt", "txt"].contains(ext.lowercased()),
              let input = job.inputs.first else { return false }
        return ["srt", "vtt"].contains(input.pathExtension.lowercased())
    }

    func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first,
              case .convert(let ext) = job.operation,
              let data = try? Data(contentsOf: input),
              let text = String(data: data, encoding: .utf8) else {
            throw EngineError.corruptInput(job.inputs.first?.lastPathComponent ?? "subtitles")
        }
        let isVTT = input.pathExtension.lowercased() == "vtt"
        let cues = Self.parse(text, isVTT: isVTT)
        guard !cues.isEmpty else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        let output: String
        switch ext.lowercased() {
        case "srt": output = Self.srt(cues)
        case "vtt": output = Self.vtt(cues)
        default: output = cues.map(\.text).joined(separator: "\n")
        }
        let destination = DestinationPolicy.outputURL(for: input, extension: ext)
        try writeAtomically(to: destination) { tmp in
            try output.write(to: tmp, atomically: true, encoding: .utf8)
        }
        progress(1)
        return [destination]
    }

    static func parse(_ text: String, isVTT: Bool) -> [SubtitleCue] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var blocks = normalized.components(separatedBy: "\n\n")
        if isVTT, let first = blocks.first,
           first.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("WEBVTT") {
            blocks.removeFirst()
        }
        var cues: [SubtitleCue] = []
        for block in blocks {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
            guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                continue
            }
            let parts = lines[timingIndex].components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = milliseconds(parts[0]),
                  let end = milliseconds(parts[1]) else { continue }
            let body = lines.dropFirst(timingIndex + 1)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            cues.append(SubtitleCue(start: start, end: end, text: body))
        }
        return cues
    }

    static func srt(_ cues: [SubtitleCue]) -> String {
        cues.enumerated().map { index, cue in
            "\(index + 1)\n\(timestamp(cue.start, separator: ",")) --> \(timestamp(cue.end, separator: ","))\n\(cue.text)"
        }.joined(separator: "\n\n") + "\n"
    }

    static func vtt(_ cues: [SubtitleCue]) -> String {
        "WEBVTT\n\n" + cues.map { cue in
            "\(timestamp(cue.start, separator: ".")) --> \(timestamp(cue.end, separator: "."))\n\(cue.text)"
        }.joined(separator: "\n\n") + "\n"
    }

    static func timestamp(_ milliseconds: Int, separator: String) -> String {
        let value = max(0, milliseconds)
        let hours = value / 3_600_000
        let minutes = (value / 60_000) % 60
        let seconds = (value / 1_000) % 60
        let millis = value % 1_000
        return String(format: "%02d:%02d:%02d\(separator)%03d", hours, minutes, seconds, millis)
    }

    static func milliseconds(_ raw: String) -> Int? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let pieces = value.split(separator: ":")
        guard pieces.count == 2 || pieces.count == 3 else { return nil }
        let last = pieces[pieces.count - 1].split(separator: ".")
        guard last.count == 2,
              let seconds = Int(last[0]),
              let fraction = Int(last[1]),
              let minutes = Int(pieces[pieces.count - 2]) else { return nil }
        let hours = pieces.count == 3 ? Int(pieces[0]) ?? 0 : 0
        return hours * 3_600_000 + minutes * 60_000 + seconds * 1_000
            + fraction * (last[1].count == 2 ? 10 : 1)
    }
}
