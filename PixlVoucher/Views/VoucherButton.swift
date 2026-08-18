import SwiftUI

/// Two-line rounded voucher button (title + subtitle + accent dot),
/// mirrors UI/RoundedButton.cs's CreateVoucherButton styling.
struct VoucherButton: View {
    let duration: VoucherDuration
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack {
                    Spacer()
                    Circle()
                        .fill(duration.accent)
                        .frame(width: 8, height: 8)
                }
                Spacer(minLength: 0)
                Text(duration.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(duration.subtitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(PixlTheme.muted)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(
                RoundedRectangle(cornerRadius: PixlTheme.buttonCornerRadius, style: .continuous)
                    .fill(PixlTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PixlTheme.buttonCornerRadius, style: .continuous)
                    .strokeBorder(PixlTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}
