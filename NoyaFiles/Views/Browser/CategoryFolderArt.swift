import NoyaCore
import SwiftUI

/// A coloured folder that stands for every file of one category.
struct CategoryFolderArt: View {
    let category: FileCategory

    var body: some View {
        let tint = category.tint
        ZStack(alignment: .bottom) {
            FolderBackShape()
                .fill(tint.gradient)
                .overlay {
                    FolderBackShape().fill(Color.black.opacity(0.22))
                }

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.gradient)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0)],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1
                        )
                }
                .overlay {
                    Image(systemName: category.symbolName)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                }
                .frame(height: 62)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
        .frame(width: 96, height: 80)
        .accessibilityHidden(true)
    }
}

/// The back of a folder, with its tab on the top left.
struct FolderBackShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 9
        let tabWidth = rect.width * 0.42
        let tabHeight: CGFloat = 9
        let bodyTop = rect.minY + tabHeight

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + tabWidth - 4, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX + tabWidth + 10, y: bodyTop),
            control1: CGPoint(x: rect.minX + tabWidth + 3, y: rect.minY),
            control2: CGPoint(x: rect.minX + tabWidth + 3, y: bodyTop)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: bodyTop))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: bodyTop + radius),
            control: CGPoint(x: rect.maxX, y: bodyTop)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 20) {
        ForEach(FileCategory.allCases, id: \.self) { category in
            CategoryFolderArt(category: category)
        }
    }
    .padding()
}
