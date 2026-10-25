import SwiftUI

enum Palette {
    static let paper = Color(uiColor: .systemGroupedBackground)
    static let green = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.58, green: 0.80, blue: 0.63, alpha: 1)
            : UIColor(red: 0.13, green: 0.38, blue: 0.29, alpha: 1)
    })
    static let button = Color(red: 0.13, green: 0.38, blue: 0.29)
    static let secondaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.75, alpha: 1)
            : UIColor(white: 0.35, alpha: 1)
    })
    static let moss = Color(red: 0.85, green: 0.91, blue: 0.82)
}

struct QuietMark: View {
    var body: some View {
        ZStack {
            Circle().fill(Palette.moss.opacity(0.4))
            Circle().strokeBorder(Palette.green.opacity(0.15), lineWidth: 1).padding(14)
            HStack(spacing: 12) {
                Capsule().fill(Palette.green).frame(width: 20, height: 70)
                Capsule().fill(Palette.green).frame(width: 20, height: 70)
            }.rotationEffect(.degrees(12))
        }
        .frame(width: 160, height: 160)
        .accessibilityHidden(true)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon = "arrow.right"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Image(systemName: icon)
            }.padding(18).frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(Palette.button, in: RoundedRectangle(cornerRadius: 18))
    }
}
