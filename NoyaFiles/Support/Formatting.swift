import Foundation

extension Int64 {
    /// A file size as the system shows it, such as "2.01 GB".
    var formattedByteCount: String {
        formatted(.byteCount(style: .file))
    }
}

@MainActor
enum DateText {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    /// A date such as "Today at 09:41" or "12 Nov 2026 at 10:03", or a dash when unknown.
    static func string(for date: Date) -> String {
        date == .distantPast ? "—" : formatter.string(from: date)
    }
}
