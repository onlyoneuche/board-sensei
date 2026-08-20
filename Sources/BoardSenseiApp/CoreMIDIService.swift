@preconcurrency import CoreMIDI
import Foundation
import MusicCore

struct MIDIDeviceDescriptor: Identifiable, Sendable, Equatable {
    let id: Int32
    let name: String
    let manufacturer: String?
    let isOnline: Bool
}

enum MIDIServiceError: LocalizedError {
    case coreMIDI(operation: String, status: OSStatus)
    case unknownDevice

    var errorDescription: String? {
        switch self {
        case let .coreMIDI(operation, status):
            "\(operation) failed with CoreMIDI status \(status)."
        case .unknownDevice:
            "The selected MIDI device is no longer available."
        }
    }
}

final class CoreMIDIService: @unchecked Sendable {
    let devices: AsyncStream<[MIDIDeviceDescriptor]>
    let events: AsyncStream<NormalizedMIDIEvent>

    private let deviceContinuation: AsyncStream<[MIDIDeviceDescriptor]>.Continuation
    private let eventContinuation: AsyncStream<NormalizedMIDIEvent>.Continuation
    private let parser = MIDINoteParser()
    private let lock = NSLock()
    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var endpoints: [Int32: MIDIEndpointRef] = [:]
    private var connectedEndpoint: MIDIEndpointRef?
    private var hasStarted = false

    init() {
        var capturedDevices: AsyncStream<[MIDIDeviceDescriptor]>.Continuation?
        devices = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { capturedDevices = $0 }
        deviceContinuation = capturedDevices!

        var capturedEvents: AsyncStream<NormalizedMIDIEvent>.Continuation?
        events = AsyncStream(bufferingPolicy: .bufferingNewest(256)) { capturedEvents = $0 }
        eventContinuation = capturedEvents!
    }

    deinit {
        if let endpoint = connectedEndpoint, inputPort != 0 {
            MIDIPortDisconnectSource(inputPort, endpoint)
        }
        if inputPort != 0 { MIDIPortDispose(inputPort) }
        if client != 0 { MIDIClientDispose(client) }
        eventContinuation.finish()
        deviceContinuation.finish()
    }

    func start() throws {
        guard !hasStarted else { return }

        var status = MIDIClientCreateWithBlock("Board Sensei MIDI" as CFString, &client) { [weak self] _ in
            self?.refreshDevices()
        }
        guard status == noErr else {
            throw MIDIServiceError.coreMIDI(operation: "Create MIDI client", status: status)
        }

        status = MIDIInputPortCreateWithBlock(client, "Board Sensei Input" as CFString, &inputPort) {
            [weak self] packetList, _ in
            self?.receive(packetList)
        }
        guard status == noErr else {
            throw MIDIServiceError.coreMIDI(operation: "Create MIDI input port", status: status)
        }

        hasStarted = true
        refreshDevices()
    }

    func connect(to deviceID: Int32) throws {
        let endpoint = lock.withLock { endpoints[deviceID] }
        guard let endpoint else { throw MIDIServiceError.unknownDevice }

        if let connectedEndpoint {
            MIDIPortDisconnectSource(inputPort, connectedEndpoint)
        }
        let status = MIDIPortConnectSource(inputPort, endpoint, nil)
        guard status == noErr else {
            throw MIDIServiceError.coreMIDI(operation: "Connect MIDI source", status: status)
        }
        connectedEndpoint = endpoint
    }

    func disconnect() {
        guard let connectedEndpoint else { return }
        MIDIPortDisconnectSource(inputPort, connectedEndpoint)
        self.connectedEndpoint = nil
    }

    private func refreshDevices() {
        var foundDevices: [MIDIDeviceDescriptor] = []
        var foundEndpoints: [Int32: MIDIEndpointRef] = [:]

        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { continue }
            var uniqueID: Int32 = 0
            MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
            let name = stringProperty(kMIDIPropertyDisplayName, for: endpoint)
                ?? stringProperty(kMIDIPropertyName, for: endpoint)
                ?? "MIDI device \(index + 1)"
            let manufacturer = stringProperty(kMIDIPropertyManufacturer, for: endpoint)
            var offline: Int32 = 0
            MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyOffline, &offline)

            foundEndpoints[uniqueID] = endpoint
            foundDevices.append(.init(
                id: uniqueID,
                name: name,
                manufacturer: manufacturer,
                isOnline: offline == 0
            ))
        }

        lock.withLock { endpoints = foundEndpoints }
        deviceContinuation.yield(foundDevices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
    }

    private func stringProperty(_ property: CFString, for object: MIDIObjectRef) -> String? {
        var value: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(object, property, &value)
        guard status == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    private func receive(_ packetList: UnsafePointer<MIDIPacketList>) {
        var packet = packetList.pointee.packet
        for _ in 0..<packetList.pointee.numPackets {
            let bytes = withUnsafeBytes(of: packet.data) { rawBuffer in
                Array(rawBuffer.prefix(Int(packet.length)))
            }
            for event in parser.parse(bytes: bytes, timestamp: packet.timeStamp) {
                eventContinuation.yield(event)
            }
            packet = MIDIPacketNext(&packet).pointee
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
