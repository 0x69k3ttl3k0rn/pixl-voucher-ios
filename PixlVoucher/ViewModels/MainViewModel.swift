import SwiftUI

enum StatusState {
    case checking
    case notConfigured
    case connected
    case offline

    var label: String {
        switch self {
        case .checking: return "Checking..."
        case .notConfigured: return "Not configured"
        case .connected: return "Connected"
        case .offline: return "Offline"
        }
    }

    var color: Color {
        switch self {
        case .checking: return PixlTheme.muted
        case .notConfigured: return PixlTheme.orange
        case .connected: return PixlTheme.green
        case .offline: return PixlTheme.red
        }
    }
}

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Drives MainView. Mirrors the flow in the Windows app's MainForm.cs:
/// create-on-MikroTik-then-print-only-on-success, with status pills for
/// both the router and the printer.
@MainActor
final class MainViewModel: ObservableObject {
    @Published var mikrotikStatus: StatusState = .checking
    @Published var printerStatus: StatusState = .checking

    @Published var lastVoucherCode: String?
    @Published var lastVoucherDuration: String?

    @Published var isBusy = false
    @Published var showSettings = false
    @Published var alert: AppAlert?

    private let settings: AppSettings
    private let mikroTik: MikroTikClient

    init(settings: AppSettings = .shared) {
        self.settings = settings
        self.mikroTik = MikroTikClient(settings: settings)
    }

    func onAppear() {
        if !CredentialStore.hasPassword() {
            showSettings = true
        }
        Task { await refreshStatuses() }
    }

    func createVoucher(_ duration: VoucherDuration) {
        guard CredentialStore.hasPassword() else {
            showSettings = true
            return
        }

        Task {
            isBusy = true
            defer { isBusy = false }

            let code = VoucherCodeGenerator.generate()

            do {
                try await mikroTik.createVoucher(
                    code: code,
                    uptime: duration.uptime,
                    description: "PIXL \(duration.displayDuration) Voucher"
                )

                lastVoucherCode = code
                lastVoucherDuration = duration.displayDuration

                do {
                    try await PrinterService.printVoucher(code: code, duration: duration.displayDuration, settings: settings)
                    printerStatus = .connected
                } catch {
                    printerStatus = .offline
                    alert = AppAlert(
                        title: "Voucher Created, Print Failed",
                        message: "\(duration.displayDuration) voucher created (\(code)), but printing failed.\n\n\(error.localizedDescription)"
                    )
                    mikrotikStatus = .connected
                    return
                }

                mikrotikStatus = .connected

                alert = AppAlert(
                    title: "PIXL Wi-Fi Voucher",
                    message: "\(duration.displayDuration) voucher created.\n\n\(code)"
                )
            } catch {
                alert = AppAlert(title: "Voucher Creation Failed", message: error.localizedDescription)
                await refreshStatuses()
            }
        }
    }

    func reprintLastVoucher() {
        guard let code = lastVoucherCode, let duration = lastVoucherDuration else {
            alert = AppAlert(title: "PIXL Wi-Fi Voucher", message: "There is no voucher to reprint.")
            return
        }

        Task {
            do {
                try await PrinterService.printVoucher(code: code, duration: duration, settings: settings)
                printerStatus = .connected
            } catch {
                printerStatus = .offline
                alert = AppAlert(title: "Reprint Failed", message: error.localizedDescription)
            }
        }
    }

    func refreshStatuses() async {
        async let mikrotik: () = refreshMikrotikStatus()
        async let printer: () = refreshPrinterStatus()
        _ = await (mikrotik, printer)
    }

    private func refreshMikrotikStatus() async {
        guard CredentialStore.hasPassword() else {
            mikrotikStatus = .notConfigured
            return
        }

        do {
            try await mikroTik.testConnection()
            mikrotikStatus = .connected
        } catch {
            mikrotikStatus = .offline
        }
    }

    private func refreshPrinterStatus() async {
        guard settings.printerPeripheralId != nil else {
            printerStatus = .notConfigured
            return
        }

        do {
            try await PrinterService.testConnection(settings: settings)
            printerStatus = .connected
        } catch {
            printerStatus = .offline
        }
    }
}
