import SwiftUI

/// A thin horizontal gauge, used for disk usage and space breakdowns.
struct UsageBar<Fill: ShapeStyle>: View {
    let fraction: Double
    let fill: Fill

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(fill)
                    .frame(width: clamped > 0 ? max(3, proxy.size.width * clamped) : 0)
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}
