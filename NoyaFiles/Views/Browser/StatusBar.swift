import SwiftUI

struct StatusBar: View {
    let model: BrowserModel

    var body: some View {
        HStack(spacing: 6) {
            Text(summary)
                .monospacedDigit()
            Spacer()
            if model.isMeasuring {
                ProgressView()
                    .controlSize(.mini)
                Text("Calculating sizes…")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 24)
    }

    private var summary: String {
        var parts: [String] = []
        let selectedCount = model.selectedItems.count
        let total = model.visibleItemCount
        if selectedCount > 0 {
            parts.append(String(localized: "\(selectedCount) of \(total) selected"))
        } else {
            parts.append(String(localized: "\(total) items"))
        }
        if let available = model.availableCapacity {
            parts.append(String(localized: "\(available.formattedByteCount) available"))
        }
        return parts.joined(separator: " · ")
    }
}
