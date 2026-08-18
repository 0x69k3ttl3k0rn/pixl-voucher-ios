import SwiftUI

/// Mirrors the "LAST VOUCHER" panel in MainForm.cs: code display + Reprint.
struct LastVoucherCard: View {
    let code: String?
    let onReprint: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("LAST VOUCHER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(PixlTheme.muted)
                Text(code ?? "No voucher created yet")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Spacer()

            Button(action: onReprint) {
                Text("REPRINT")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(PixlTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .pixlCard()
    }
}
