import CoreBluetooth
import Combine

/// CoreBluetooth wrapper for a BLE ESC/POS receipt printer. Deliberately
/// generic: rather than hardcoding one vendor's service/characteristic
/// UUIDs (cheap BLE printer modules vary a lot), it discovers all services
/// on the paired peripheral and writes to the first characteristic that
/// supports .write or .writeWithoutResponse.
final class PrinterManager: NSObject, ObservableObject {
    static let shared = PrinterManager()

    struct DiscoveredPrinter: Identifiable, Equatable {
        let id: UUID
        let name: String
        let rssi: Int

        static func == (lhs: DiscoveredPrinter, rhs: DiscoveredPrinter) -> Bool {
            lhs.id == rhs.id
        }
    }

    @Published private(set) var discovered: [DiscoveredPrinter] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isBluetoothReady = false

    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]

    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var pendingServiceCount = 0

    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var writeContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        discovered = []
        guard central.state == .poweredOn else { return }
        isScanning = true
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        isScanning = false
        central.stopScan()
    }

    func select(_ printer: DiscoveredPrinter, settings: AppSettings) {
        settings.printerPeripheralId = printer.id.uuidString
        settings.printerName = printer.name
    }

    /// Connects to the printer saved in Settings, discovers services, and
    /// leaves the manager holding a writable characteristic ready for
    /// `print(data:)`. Used both by the real print flow and by Settings'
    /// "Test Connection" check.
    func connectToSavedPrinter(settings: AppSettings) async throws {
        guard let idString = settings.printerPeripheralId, let uuid = UUID(uuidString: idString) else {
            throw PrinterError.notConfigured
        }
        guard central.state == .poweredOn else {
            throw PrinterError.bluetoothUnavailable
        }

        let known = central.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = known.first else {
            throw PrinterError.printerNotFound
        }

        try await connect(peripheral)
    }

    func print(data: Data, settings: AppSettings) async throws {
        try await connectToSavedPrinter(settings: settings)

        guard let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else {
            throw PrinterError.noWritableCharacteristic
        }

        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        let maxLength = peripheral.maximumWriteValueLength(for: writeType)
        let chunkSize = max(20, maxLength)

        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunk = data.subdata(in: offset..<end)

            if writeType == .withResponse {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    self.writeContinuation = continuation
                    peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
                }
            } else {
                peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
                // Cheap BLE printer modules have small buffers; a short
                // pause between unacknowledged chunks avoids overrunning them.
                try await Task.sleep(nanoseconds: 20_000_000)
            }

            offset = end
        }

        // Give the printer a moment to flush its buffer to paper before we
        // tear down the link — cutting the connection the instant the last
        // BLE write lands can truncate the tail of the receipt on some
        // cheap printer modules.
        try? await Task.sleep(nanoseconds: 300_000_000)

        disconnectCurrent()
    }

    private func connect(_ peripheral: CBPeripheral) async throws {
        disconnectCurrent()
        connectedPeripheral = peripheral
        writeCharacteristic = nil
        peripheral.delegate = self

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectContinuation = continuation
            self.central.connect(peripheral, options: nil)
        }
    }

    private func disconnectCurrent() {
        if let peripheral = connectedPeripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        writeCharacteristic = nil
    }

    private func failConnect(_ error: Error) {
        guard let continuation = connectContinuation else { return }
        connectContinuation = nil
        continuation.resume(throwing: error)
    }

    private func succeedConnect() {
        guard let continuation = connectContinuation else { return }
        connectContinuation = nil
        continuation.resume()
    }
}

enum PrinterError: LocalizedError {
    case notConfigured
    case bluetoothUnavailable
    case printerNotFound
    case noWritableCharacteristic
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No printer selected. Choose one in Settings."
        case .bluetoothUnavailable:
            return "Bluetooth is off or unavailable."
        case .printerNotFound:
            return "Saved printer wasn't found nearby. Make sure it's powered on."
        case .noWritableCharacteristic:
            return "Connected, but the printer didn't expose a writable characteristic."
        case .connectionFailed:
            return "Couldn't connect to the printer."
        }
    }
}

extension PrinterManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothReady = central.state == .poweredOn
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name, !name.isEmpty else { return }

        peripherals[peripheral.identifier] = peripheral
        let printer = DiscoveredPrinter(id: peripheral.identifier, name: name, rssi: RSSI.intValue)

        if let index = discovered.firstIndex(where: { $0.id == printer.id }) {
            discovered[index] = printer
        } else {
            discovered.append(printer)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        pendingServiceCount = 0
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        failConnect(error ?? PrinterError.connectionFailed)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let disconnectError = error ?? PrinterError.connectionFailed
        failConnect(disconnectError)

        // An unexpected disconnect mid-print would otherwise leave `print`
        // awaiting a write acknowledgement that can never arrive.
        if let continuation = writeContinuation {
            writeContinuation = nil
            continuation.resume(throwing: disconnectError)
        }
    }
}

extension PrinterManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            failConnect(error)
            return
        }

        guard let services = peripheral.services, !services.isEmpty else {
            failConnect(PrinterError.noWritableCharacteristic)
            return
        }

        pendingServiceCount = services.count
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        pendingServiceCount -= 1

        if writeCharacteristic == nil,
           let characteristic = service.characteristics?.first(where: {
               $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse)
           }) {
            writeCharacteristic = characteristic
            succeedConnect()
            return
        }

        if pendingServiceCount <= 0 && writeCharacteristic == nil {
            failConnect(PrinterError.noWritableCharacteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let continuation = writeContinuation else { return }
        writeContinuation = nil

        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}
