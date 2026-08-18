import Foundation

/// Generates voucher codes identical in shape to GenerateVoucherCode() in
/// the Windows app's MainForm.cs: "PXL" + 3 chars from an ambiguity-free
/// charset, drawn from a CSPRNG.
enum VoucherCodeGenerator {
    // Avoid characters commonly confused on printed receipts (no I/O/0/1).
    private static let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        var rng = SystemRandomNumberGenerator()
        let suffix = (0..<3).map { _ in chars[Int.random(in: 0..<chars.count, using: &rng)] }
        return "PXL" + String(suffix)
    }
}
