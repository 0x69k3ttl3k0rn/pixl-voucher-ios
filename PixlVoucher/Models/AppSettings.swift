import Foundation
import Combine

/// Non-secret configuration, persisted in UserDefaults. The MikroTik API
/// password is deliberately NOT here — see CredentialStore (Keychain).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let mikrotikHost = "mikrotikHost"
        static let mikrotikUser = "mikrotikUser"
        static let hotspotProfile = "hotspotProfile"
        static let trustSelfSignedCert = "trustSelfSignedCert"
        static let printerPeripheralId = "printerPeripheralId"
        static let printerName = "printerName"
    }

    private let defaults: UserDefaults

    @Published var mikrotikHost: String {
        didSet { defaults.set(mikrotikHost, forKey: Keys.mikrotikHost) }
    }

    /// Fixed router API username, kept in sync with MainForm.MikrotikUser
    /// on the Windows app. Not a secret by itself.
    @Published var mikrotikUser: String {
        didSet { defaults.set(mikrotikUser, forKey: Keys.mikrotikUser) }
    }

    @Published var hotspotProfile: String {
        didSet { defaults.set(hotspotProfile, forKey: Keys.hotspotProfile) }
    }

    /// RouterOS on a closed LAN typically serves a self-signed cert. On by
    /// default since this app only ever talks to a local, known device.
    @Published var trustSelfSignedCert: Bool {
        didSet { defaults.set(trustSelfSignedCert, forKey: Keys.trustSelfSignedCert) }
    }

    /// CBPeripheral.identifier.uuidString of the paired BLE printer, if any.
    @Published var printerPeripheralId: String? {
        didSet { defaults.set(printerPeripheralId, forKey: Keys.printerPeripheralId) }
    }

    /// Cached display name for the picked printer (peripheral.name at the
    /// time it was selected), so Settings can show it without rescanning.
    @Published var printerName: String? {
        didSet { defaults.set(printerName, forKey: Keys.printerName) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.mikrotikHost = defaults.string(forKey: Keys.mikrotikHost) ?? "192.168.88.1"
        self.mikrotikUser = defaults.string(forKey: Keys.mikrotikUser) ?? "pixl-voucher"
        self.hotspotProfile = defaults.string(forKey: Keys.hotspotProfile) ?? "PIXL-Guest"
        self.trustSelfSignedCert = defaults.object(forKey: Keys.trustSelfSignedCert) as? Bool ?? true
        self.printerPeripheralId = defaults.string(forKey: Keys.printerPeripheralId)
        self.printerName = defaults.string(forKey: Keys.printerName)
    }
}
