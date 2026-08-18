import SwiftUI

/// MikroTik + printer setup, mirrors MikrotikSetupForm.cs plus a BLE
/// printer picker (the Windows app has no printer setup screen since the
/// POS-58 is a Windows-installed USB printer).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var printerManager = PrinterManager.shared

    let onClose: () -> Void

    @State private var host = ""
    @State private var password = ""

    @State private var mikrotikTestResult = ""
    @State private var mikrotikTestColor = PixlTheme.muted
    @State private var isTestingMikrotik = false

    @State private var printerTestResult = ""
    @State private var printerTestColor = PixlTheme.muted
    @State private var isTestingPrinter = false

    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                mikrotikSection
                printerSection
            }
            .scrollContentBackground(.hidden)
            .background(PixlTheme.background)
            .navigationTitle("PIXL Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onClose()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .alert("Couldn't Save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
        .onAppear {
            host = settings.mikrotikHost
        }
    }

    private var mikrotikSection: some View {
        Section {
            TextField("MikroTik Host", text: $host)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            SecureField("MikroTik API Password", text: $password)

            Toggle("Trust self-signed certificate", isOn: $settings.trustSelfSignedCert)

            Button {
                testMikrotik()
            } label: {
                if isTestingMikrotik {
                    ProgressView()
                } else {
                    Text("TEST CONNECTION")
                }
            }
            .disabled(isTestingMikrotik || host.isEmpty || password.isEmpty)

            if !mikrotikTestResult.isEmpty {
                Text(mikrotikTestResult)
                    .foregroundColor(mikrotikTestColor)
                    .font(.footnote.bold())
            }
        } header: {
            Text("MikroTik Router")
        } footer: {
            Text("Enter the API password for the \(settings.mikrotikUser) user. Requires RouterOS 7.1+ with the www-ssl service enabled.")
        }
    }

    private var printerSection: some View {
        Section {
            if let name = settings.printerName {
                HStack {
                    Text("Selected Printer")
                    Spacer()
                    Text(name).foregroundColor(PixlTheme.muted)
                }
            }

            Button {
                testPrinter()
            } label: {
                if isTestingPrinter {
                    ProgressView()
                } else {
                    Text("TEST CONNECTION")
                }
            }
            .disabled(isTestingPrinter || settings.printerPeripheralId == nil)

            if !printerTestResult.isEmpty {
                Text(printerTestResult)
                    .foregroundColor(printerTestColor)
                    .font(.footnote.bold())
            }

            Button(printerManager.isScanning ? "Scanning..." : "SCAN FOR PRINTERS") {
                printerManager.startScan()
            }
            .disabled(printerManager.isScanning || !printerManager.isBluetoothReady)

            if !printerManager.isBluetoothReady {
                Text("Turn on Bluetooth to scan for printers.")
                    .font(.footnote)
                    .foregroundColor(PixlTheme.orange)
            }

            ForEach(printerManager.discovered) { printer in
                Button {
                    printerManager.stopScan()
                    printerManager.select(printer, settings: settings)
                } label: {
                    HStack {
                        Text(printer.name)
                        Spacer()
                        Text("\(printer.rssi) dBm").foregroundColor(PixlTheme.muted).font(.footnote)
                    }
                }
            }
        } header: {
            Text("Receipt Printer (Bluetooth)")
        } footer: {
            Text("Scan and select your BLE receipt printer. It must be powered on and advertising.")
        }
    }

    private func testMikrotik() {
        isTestingMikrotik = true
        mikrotikTestResult = "● Testing..."
        mikrotikTestColor = PixlTheme.muted

        Task {
            defer { isTestingMikrotik = false }
            do {
                try await MikroTikClient(settings: settings).testConnection(host: host, password: password)
                mikrotikTestResult = "● Connected"
                mikrotikTestColor = PixlTheme.green
            } catch {
                mikrotikTestResult = "● \(error.localizedDescription)"
                mikrotikTestColor = PixlTheme.red
            }
        }
    }

    private func testPrinter() {
        isTestingPrinter = true
        printerTestResult = "● Testing..."
        printerTestColor = PixlTheme.muted

        Task {
            defer { isTestingPrinter = false }
            do {
                try await PrinterService.testConnection(settings: settings)
                printerTestResult = "● Connected"
                printerTestColor = PixlTheme.green
            } catch {
                printerTestResult = "● \(error.localizedDescription)"
                printerTestColor = PixlTheme.red
            }
        }
    }

    private func save() {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            saveError = "Enter the MikroTik host."
            return
        }
        guard !password.isEmpty else {
            saveError = "Enter the MikroTik API password."
            return
        }

        do {
            try CredentialStore.savePassword(password)
            settings.mikrotikHost = host
            password = ""
            dismiss()
            onClose()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView(onClose: {})
}
