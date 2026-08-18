import SwiftUI

/// The six quick-voucher options, matching MainForm.cs's button set exactly:
/// same uptime strings, same subtitle labels, same accent colors.
struct VoucherDuration: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let uptime: String
    let displayDuration: String
    let accent: Color

    static let all: [VoucherDuration] = [
        VoucherDuration(title: "5 MIN", subtitle: "OTP / AUTH", uptime: "5m", displayDuration: "5 MINUTES", accent: PixlTheme.pink),
        VoucherDuration(title: "30 MIN", subtitle: "QUICK ACCESS", uptime: "30m", displayDuration: "30 MINUTES", accent: PixlTheme.blue),
        VoucherDuration(title: "1 HOUR", subtitle: "STANDARD", uptime: "1h", displayDuration: "1 HOUR", accent: PixlTheme.purple),
        VoucherDuration(title: "3 HOURS", subtitle: "EXTENDED", uptime: "3h", displayDuration: "3 HOURS", accent: PixlTheme.blue),
        VoucherDuration(title: "5 HOURS", subtitle: "EXTENDED", uptime: "5h", displayDuration: "5 HOURS", accent: PixlTheme.purple),
        VoucherDuration(title: "DAY PASS", subtitle: "12 HOURS", uptime: "12h", displayDuration: "DAY PASS", accent: PixlTheme.pink),
    ]
}
