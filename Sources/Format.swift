import Foundation

/// Byte counts and speeds as text.
enum Format {
    static func bytes(_ n: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false // "0 bytes", not "Zero KB"
        return formatter.string(fromByteCount: Int64(clamping: n))
    }

    /// Bits per second in the unit a person expects on a speed test.
    static func speed(_ bps: Double) -> String {
        switch bps {
        case 1e6...: return String(format: "%.1f Mbit/s", bps / 1e6)
        case 1e3...: return String(format: "%.0f kbit/s", bps / 1e3)
        default: return String(format: "%.0f bit/s", bps)
        }
    }
}
