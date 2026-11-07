import Foundation
import Compression

// MARK: - CRC32

private enum CRC32 {
    static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) == 1 ? (value >> 1) ^ 0xEDB8_8320 : value >> 1
        }
        return value
    }

    static func checksum(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xFF)]
        }
        return crc ^ 0xFFFF_FFFF
    }
}

// MARK: - Writer

/// Small store-only ZIP writer. EPUB and OOXML readers accept stored entries;
/// keeping all entries uncompressed also makes `mimetype` legal in EPUB/ODS.
struct ZipWriter {
    private struct Entry {
        let name: String
        let bytes: [UInt8]
        let crc: UInt32
        let offset: UInt32
    }

    private var body = Data()
    private var entries: [Entry] = []

    mutating func add(_ name: String, _ data: Data) {
        guard let nameBytes = name.data(using: .utf8) else { return }
        let bytes = Array(data)
        let crc = CRC32.checksum(bytes)
        let offset = UInt32(body.count)

        body.appendLE(UInt32(0x0403_4B50))
        body.appendLE(UInt16(20))
        body.appendLE(UInt16(0x0800)) // UTF-8 names
        body.appendLE(UInt16(0))      // stored
        body.appendLE(UInt16(0))      // time
        body.appendLE(UInt16(0x21))   // 1980-01-01
        body.appendLE(crc)
        body.appendLE(UInt32(bytes.count))
        body.appendLE(UInt32(bytes.count))
        body.appendLE(UInt16(nameBytes.count))
        body.appendLE(UInt16(0))
        body.append(contentsOf: nameBytes)
        body.append(contentsOf: bytes)

        entries.append(
            Entry(name: name, bytes: bytes, crc: crc, offset: offset)
        )
    }

    mutating func add(_ name: String, _ text: String) {
        add(name, Data(text.utf8))
    }

    func data() -> Data {
        var archive = body
        let directoryOffset = UInt32(archive.count)

        for entry in entries {
            guard let nameBytes = entry.name.data(using: .utf8) else { continue }
            archive.appendLE(UInt32(0x0201_4B50))
            archive.appendLE(UInt16(20))
            archive.appendLE(UInt16(20))
            archive.appendLE(UInt16(0x0800))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0x21))
            archive.appendLE(entry.crc)
            archive.appendLE(UInt32(entry.bytes.count))
            archive.appendLE(UInt32(entry.bytes.count))
            archive.appendLE(UInt16(nameBytes.count))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt32(0))
            archive.appendLE(entry.offset)
            archive.append(contentsOf: nameBytes)
        }

        let directorySize = UInt32(archive.count) - directoryOffset
        archive.appendLE(UInt32(0x0605_4B50))
        archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(entries.count))
        archive.appendLE(UInt16(entries.count))
        archive.appendLE(directorySize)
        archive.appendLE(directoryOffset)
        archive.appendLE(UInt16(0))
        return archive
    }

    func write(to url: URL) throws {
        try data().write(to: url, options: .atomic)
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { raw in
            append(contentsOf: raw)
        }
    }
}

// MARK: - Reader

struct ZipReader {
    private struct Entry {
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localOffset: Int
    }

    private let bytes: [UInt8]
    private var entries: [String: Entry] = [:]
    private var order: [String] = []

    init?(data: Data) {
        bytes = Array(data)
        guard parseCentralDirectory() else { return nil }
    }

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        self.init(data: data)
    }

    var names: [String] { order }

    func contains(_ name: String) -> Bool {
        entries[name] != nil
    }

    func read(_ name: String) -> Data? {
        guard let entry = entries[name] else { return nil }
        guard entry.localOffset >= 0, entry.localOffset + 30 <= bytes.count else {
            return nil
        }
        guard read32(entry.localOffset) == 0x0403_4B50 else { return nil }
        let nameLength = Int(read16(entry.localOffset + 26))
        let extraLength = Int(read16(entry.localOffset + 28))
        let start = entry.localOffset + 30 + nameLength + extraLength
        guard start >= 0, start + entry.compressedSize <= bytes.count else {
            return nil
        }
        let payload = Array(bytes[start..<(start + entry.compressedSize)])

        switch entry.method {
        case 0:
            return Data(payload)
        case 8:
            return Self.inflate(payload, expected: entry.uncompressedSize)
        default:
            return nil
        }
    }

    func readText(_ name: String) -> String? {
        guard let data = read(name) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private mutating func parseCentralDirectory() -> Bool {
        guard bytes.count >= 22 else { return false }
        let minimum = max(0, bytes.count - 65_557)
        var eocd = -1
        var index = bytes.count - 22
        while index >= minimum {
            if read32(index) == 0x0605_4B50 {
                eocd = index
                break
            }
            index -= 1
        }
        guard eocd >= 0 else { return false }

        let count = Int(read16(eocd + 10))
        let directoryOffset = Int(read32(eocd + 16))
        guard directoryOffset >= 0, directoryOffset < bytes.count else { return false }

        var cursor = directoryOffset
        for _ in 0..<count {
            guard cursor + 46 <= bytes.count else { return false }
            guard read32(cursor) == 0x0201_4B50 else { return false }
            let method = read16(cursor + 10)
            let compressed = Int(read32(cursor + 20))
            let uncompressed = Int(read32(cursor + 24))
            let nameLength = Int(read16(cursor + 28))
            let extraLength = Int(read16(cursor + 30))
            let commentLength = Int(read16(cursor + 32))
            let localOffset = Int(read32(cursor + 42))
            let nameStart = cursor + 46
            guard nameStart + nameLength <= bytes.count else { return false }
            let nameBytes = Array(bytes[nameStart..<(nameStart + nameLength)])
            let name = String(bytes: nameBytes, encoding: .utf8)
                ?? String(bytes: nameBytes, encoding: .isoLatin1)
                ?? ""

            if !name.isEmpty {
                entries[name] = Entry(
                    method: method,
                    compressedSize: compressed,
                    uncompressedSize: uncompressed,
                    localOffset: localOffset
                )
                order.append(name)
            }
            cursor = nameStart + nameLength + extraLength + commentLength
        }
        return true
    }

    private func read16(_ offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= bytes.count else { return 0 }
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private func read32(_ offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= bytes.count else { return 0 }
        return UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }

    private static func inflate(_ input: [UInt8], expected: Int) -> Data? {
        guard !input.isEmpty else { return Data() }
        guard expected > 0 else { return Data() }

        var output = [UInt8](repeating: 0, count: expected)
        let written = input.withUnsafeBufferPointer { source in
            output.withUnsafeMutableBufferPointer { destination in
                compression_decode_buffer(
                    destination.baseAddress!,
                    expected,
                    source.baseAddress!,
                    input.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard written > 0 else { return nil }
        return Data(output.prefix(written))
    }
}
