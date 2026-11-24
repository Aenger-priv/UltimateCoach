import CoreBluetooth
import Observation

@MainActor @Observable
final class PM5Connection: NSObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    enum State: Equatable { case idle, searching, connecting, sending, ready, failed(String) }
    private(set) var state = State.idle
    private(set) var monitors: [CBPeripheral] = []

    private var central: CBCentralManager?
    private var selected: CBPeripheral?
    private var receive: CBCharacteristic?
    private var transmit: CBCharacteristic?
    private var commands: ArraySlice<PM5Command> = []
    private var remaining = Data()
    private var incoming = Data()
    private var deadline: Task<Void, Never>?
    private var deferredIO: Task<Void, Never>?
    private var writePending = false
    private var replyAccepted = false

    private static func uuid(_ short: String) -> CBUUID { CBUUID(string: "CE06\(short)-43E5-11E4-916C-0800200C9A66") }
    private static let control = uuid("0020")
    private static let writeID = uuid("0021")
    private static let responseID = uuid("0022")

    func search() {
        stop()
        state = .searching
        monitors.removeAll()
        if let central {
            centralManagerDidUpdateState(central)
        } else {
            // The system asks for Bluetooth access only after the person chooses Find a PM5.
            central = CBCentralManager(delegate: self, queue: .main,
                                       options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
    }

    func send(_ workout: RowingWorkout, to monitor: CBPeripheral) {
        let setup = PM5Command.program(workout)
        guard state == .searching, !setup.isEmpty, central?.state == .poweredOn else { return }
        central?.stopScan()
        selected = monitor
        monitor.delegate = self
        commands = ([PM5Command.checkMonitor] + setup + [PM5Command.confirmType(of: workout)])[...]
        state = .connecting
        central?.connect(monitor)
        timeout(after: 12, message: "Couldn’t connect. Open Connect on the PM5 and disconnect any other training app.")
    }

    func stop() {
        deadline?.cancel()
        deferredIO?.cancel()
        if central?.isScanning == true { central?.stopScan() }
        if let selected {
            selected.delegate = nil
            central?.cancelPeripheralConnection(selected)
        }
        selected = nil
        transmit = nil
        receive = nil
        commands = []
        writePending = false
        replyAccepted = false
        incoming.removeAll()
        remaining.removeAll()
        state = .idle
    }

    private func fail(_ message: String) {
        stop()
        state = .failed(message)
    }

    private func timeout(after seconds: Int, message: String) {
        deadline?.cancel()
        deadline = Task {
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            // Keep the discovered monitor choices available while the user is deciding.
            if state == .searching, !monitors.isEmpty { central?.stopScan(); return }
            fail(message)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard state != .idle, state != .ready else { return }
        switch central.state {
        case .poweredOn:
            guard state == .searching else { return }
            central.scanForPeripherals(withServices: [Self.uuid("0000"), Self.control, Self.uuid("0030")])
            timeout(after: 15, message: "No PM5 found. On your RowErg, open Connect, then search again.")
        case .poweredOff: fail("Turn on Bluetooth on your iPhone, then search again.")
        case .unauthorized: fail("Allow Bluetooth for UltimateCoach in iPhone Settings, or use manual setup below.")
        case .unsupported: fail("Bluetooth is unavailable on this device. Use manual setup below.")
        case .resetting, .unknown:
            timeout(after: 15, message: "Bluetooth is still starting. Try again or use manual setup below.")
        @unknown default: fail("Bluetooth is unavailable. Use manual setup below.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard state == .searching, !monitors.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        monitors.append(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral == selected else { return }
        peripheral.discoverServices([Self.control])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral == selected else { return }
        fail("Couldn’t connect to this PM5. Check its Connect screen and try again.")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral == selected else { return }
        fail("The PM5 disconnected. Check the workout on the monitor before trying again.")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral == selected else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.control }) else {
            return fail("This monitor didn’t offer Concept2 workout setup. Use manual setup below.")
        }
        peripheral.discoverCharacteristics([Self.writeID, Self.responseID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral == selected else { return }
        receive = service.characteristics?.first { $0.uuid == Self.writeID }
        transmit = service.characteristics?.first { $0.uuid == Self.responseID }
        guard error == nil, receive?.properties.contains(.write) == true, let transmit else {
            return fail("This PM5 couldn’t accept a workout. Use manual setup below.")
        }
        if transmit.properties.contains(.notify) || transmit.properties.contains(.indicate) {
            peripheral.setNotifyValue(true, for: transmit)
        } else if transmit.properties.contains(.read) {
            beginFrame()
        } else {
            fail("This PM5 couldn’t confirm workout setup. Use manual setup below.")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == selected, characteristic == transmit else { return }
        guard error == nil, characteristic.isNotifying else { return fail("The PM5 couldn’t confirm workout setup.") }
        beginFrame()
    }

    private func beginFrame() {
        guard let command = commands.first else { return }
        state = .sending
        remaining = command.frame
        incoming.removeAll()
        replyAccepted = false
        timeout(after: 4, message: "The PM5 didn’t confirm setup. Check its screen before trying again.")
        writeChunk()
    }

    private func writeChunk() {
        guard let selected, let receive, !remaining.isEmpty else { return }
        let size = min(20, selected.maximumWriteValueLength(for: .withResponse))
        let chunk = remaining.prefix(size)
        remaining.removeFirst(chunk.count)
        writePending = true
        selected.writeValue(chunk, for: receive, type: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == selected, characteristic == receive, writePending else { return }
        writePending = false
        guard error == nil else { return fail("The PM5 couldn’t receive the workout. Check its screen and try again.") }
        if !remaining.isEmpty {
            writeChunk()
        } else if replyAccepted {
            advance()
        } else if let transmit, !transmit.isNotifying {
            deferredIO = Task {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                peripheral.readValue(for: transmit)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == selected, characteristic == transmit, let command = commands.first else { return }
        guard error == nil, let data = characteristic.value else { return fail("Couldn’t read the PM5 response.") }
        incoming.append(data)
        guard incoming.count <= 120 else { return fail("The PM5 returned an unreadable response.") }
        guard incoming.last == 0xF2 else {
            if !characteristic.isNotifying {
                deferredIO = Task {
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                    peripheral.readValue(for: characteristic)
                }
            }
            return
        }
        switch command.response(to: incoming) {
        case .busy: fail("A workout is already active on the PM5. Finish it there before sending a new one.")
        case .invalid: fail("The PM5 didn’t confirm this workout. Check its screen or use manual setup.")
        case .accepted:
            replyAccepted = true
            if !writePending, remaining.isEmpty { advance() }
        }
    }

    private func advance() {
        deadline?.cancel()
        commands.removeFirst()
        if commands.isEmpty {
            stop()
            state = .ready
        } else {
            deferredIO = Task {
                do { try await Task.sleep(for: .milliseconds(75)) } catch { return }
                beginFrame()
            }
        }
    }
}
