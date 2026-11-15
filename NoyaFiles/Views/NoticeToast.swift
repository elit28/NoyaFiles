import SwiftUI

/// A short message in the corner of the window, such as “3 items moved to the Trash — Undo”.
struct NoticeToast: View {
    let notice: Notice
    let perform: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notice.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(notice.message)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let actionTitle = notice.actionTitle {
                Button(actionTitle, action: perform)
                    .buttonStyle(.link)
                    .fontWeight(.semibold)
            }
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
        }
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .accessibilityElement(children: .contain)
    }
}
