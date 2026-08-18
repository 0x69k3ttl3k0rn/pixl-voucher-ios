import SwiftUI

/// PIXL brand palette and shared styling, matching the WinForms app's
/// hardcoded colors in MainForm.cs / MikrotikSetupForm.cs.
enum PixlTheme {
    static let background = Color(red: 5 / 255, green: 9 / 255, blue: 24 / 255)
    static let panel = Color(red: 13 / 255, green: 20 / 255, blue: 42 / 255)
    static let blue = Color(red: 29 / 255, green: 125 / 255, blue: 255 / 255)
    static let pink = Color(red: 255 / 255, green: 45 / 255, blue: 100 / 255)
    static let purple = Color(red: 132 / 255, green: 62 / 255, blue: 255 / 255)
    static let muted = Color(red: 165 / 255, green: 175 / 255, blue: 205 / 255)
    static let green = Color(red: 70 / 255, green: 220 / 255, blue: 130 / 255)
    static let red = Color(red: 255 / 255, green: 80 / 255, blue: 100 / 255)
    static let orange = Color(red: 255 / 255, green: 190 / 255, blue: 60 / 255)
    static let border = Color(red: 35 / 255, green: 45 / 255, blue: 75 / 255)

    static let cornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 14
}

/// Rounded card background, mirrors UI/RoundedPanel.cs.
struct PixlCard: ViewModifier {
    var fill: Color = PixlTheme.panel
    var cornerRadius: CGFloat = PixlTheme.cornerRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
    }
}

extension View {
    func pixlCard(fill: Color = PixlTheme.panel, cornerRadius: CGFloat = PixlTheme.cornerRadius) -> some View {
        modifier(PixlCard(fill: fill, cornerRadius: cornerRadius))
    }
}
