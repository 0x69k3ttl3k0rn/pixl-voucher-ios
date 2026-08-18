import Foundation

/// Builds the ESC/POS receipt payload and sends it via PrinterManager.
/// Mirrors the receipt layout drawn by PrintVoucher() in the Windows app's
/// MainForm.cs (same lines, same order).
enum PrinterService {
    private static let esc: UInt8 = 0x1B
    private static let gs: UInt8 = 0x1D

    static func printVoucher(code: String, duration: String, settings: AppSettings = .shared) async throws {
        let payload = buildReceipt(code: code, duration: duration, ssid: settings.hotspotProfile)
        try await PrinterManager.shared.print(data: payload, settings: settings)
    }

    /// Connects to the saved printer just far enough to confirm it's
    /// reachable and has a writable characteristic, without printing
    /// anything. Used by Settings' "Test Connection".
    static func testConnection(settings: AppSettings = .shared) async throws {
        try await PrinterManager.shared.connectToSavedPrinter(settings: settings)
    }

    private static func buildReceipt(code: String, duration: String, ssid: String) -> Data {
        var bytes: [UInt8] = []

        bytes += [esc, 0x40] // ESC @ — initialize printer

        appendLine(&bytes, "PIXL GAMING CAFE", bold: true)
        appendLine(&bytes, "GUEST WI-FI VOUCHER", bold: false)
        appendLine(&bytes, duration, bold: true)
        bytes += [0x0A]
        appendLine(&bytes, "VOUCHER CODE:", bold: false)
        appendLine(&bytes, code, bold: true, doubleSize: true)
        bytes += [0x0A]
        appendLine(&bytes, "Wi-Fi: \(ssid)", bold: false)
        appendLine(&bytes, "Enter this code on the", bold: false)
        appendLine(&bytes, "PIXL Wi-Fi login page.", bold: false)
        bytes += [0x0A]
        appendLine(&bytes, "Thank you!", bold: false)

        bytes += [esc, 0x64, 3] // ESC d 3 — feed 3 lines
        bytes += [gs, 0x56, 0x42, 0x00] // GS V 66 0 — partial cut

        return Data(bytes)
    }

    private static func appendLine(_ bytes: inout [UInt8], _ text: String, bold: Bool, doubleSize: Bool = false) {
        bytes += [esc, 0x45, bold ? 1 : 0] // ESC E n — emphasized (bold) on/off
        bytes += [gs, 0x21, doubleSize ? 0x11 : 0x00] // GS ! n — double width+height on/off
        bytes += Array(text.utf8)
        bytes += [0x0A]
    }
}
