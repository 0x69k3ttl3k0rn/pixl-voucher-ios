import SwiftUI

/// "● Label: Status" status line, mirrors lblMikrotikStatus/lblPrinterStatus
/// in MainForm.cs.
struct StatusPill: View {
    let label: String
    let status: StatusState

    var body: some View {
        HStack(spacing: 4) {
            Text("●")
                .foregroundColor(status.color)
            Text("\(label): \(status.label)")
                .foregroundColor(PixlTheme.muted)
        }
        .font(.system(size: 13))
    }
}
