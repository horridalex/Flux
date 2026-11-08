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
        let (number, unit) = speedParts(bps)
        return "\(number) \(unit)"
    }

    /// `speed` split in two, for a big number with its unit small beside it.
    static func speedParts(_ bps: Double) -> (number: String, unit: String) {
        switch bps {
        case 1e6...: return (String(format: "%.1f", bps / 1e6), "Mbit/s")
        case 1e3...: return (String(format: "%.0f", bps / 1e3), "kbit/s")
        default: return (String(format: "%.0f", bps), "bit/s")
        }
    }
}
