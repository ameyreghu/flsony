import Cocoa
import FlutterMacOS
import IOBluetooth

/// Byte pipe between Dart and Sony's proprietary RFCOMM service
/// ("Serial HPC"). All protocol logic lives in Dart; see lib/core.
final class BluetoothPlugin: NSObject, FlutterStreamHandler {
  private static let nameHints = ["WH-1000XM4", "WH-1000XM5", "WH-1000XM3"]
  private static let serviceUUID: [UInt8] = [
    0x96, 0xCC, 0x20, 0x3E, 0x50, 0x68, 0x46, 0xAD,
    0xB3, 0x2D, 0xE3, 0x16, 0xF5, 0xE0, 0x69, 0xBA,
  ]

  private var sink: FlutterEventSink?
  private var channel: IOBluetoothRFCOMMChannel?
  private var connecting = false
  private var rfcommChannelID: BluetoothRFCOMMChannelID = 0
  private var connectNote: IOBluetoothUserNotification?
  private var disconnectNote: IOBluetoothUserNotification?

  static func register(with messenger: FlutterBinaryMessenger) {
    let plugin = BluetoothPlugin()
    let method = FlutterMethodChannel(name: "flsony/bt", binaryMessenger: messenger)
    method.setMethodCallHandler { call, result in plugin.handle(call, result) }
    FlutterEventChannel(name: "flsony/bt/events", binaryMessenger: messenger).setStreamHandler(plugin)
    // The channel objects only hold weak refs to the plugin on the Dart side.
    objc_setAssociatedObject(method, &Self.retainKey, plugin, .OBJC_ASSOCIATION_RETAIN)
  }
  private static var retainKey: UInt8 = 0

  // MARK: Flutter plumbing

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "startMonitoring": startMonitoring()
    case "connect": connect()
    case "disconnect": disconnect()
    case "send":
      if let data = (call.arguments as? FlutterStandardTypedData)?.data { write(data) }
    default:
      return result(FlutterMethodNotImplemented)
    }
    result(nil)
  }

  private func emit(_ event: [String: Any]) { sink?(event) }

  private func status(_ state: String, name: String? = nil, reason: String? = nil, details: [String: String]? = nil) {
    var e: [String: Any] = ["type": "status", "state": state]
    if let name = name { e["name"] = name }
    if let reason = reason { e["reason"] = reason }
    if let details = details { e["details"] = details }
    emit(e)
  }

  // MARK: Device lookup + reachability

  private func isTarget(_ device: IOBluetoothDevice) -> Bool {
    let name = device.name ?? ""
    return Self.nameHints.contains { name.contains($0) }
  }

  private func targetDevice() -> IOBluetoothDevice? {
    (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice])?.first(where: isTarget)
  }

  private func startMonitoring() {
    connectNote = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(aclConnected(_:device:)))
    if let d = targetDevice(), d.isConnected() {
      watchDisconnect(d)
      emit(["type": "reachable", "value": true, "name": d.name ?? ""])
    } else {
      emit(["type": "reachable", "value": false])
    }
  }

  private func watchDisconnect(_ d: IOBluetoothDevice) {
    disconnectNote?.unregister()
    disconnectNote = d.register(forDisconnectNotification: self, selector: #selector(aclDisconnected(_:device:)))
  }

  @objc private func aclConnected(_ n: IOBluetoothUserNotification, device: IOBluetoothDevice) {
    guard isTarget(device) else { return }
    watchDisconnect(device)
    emit(["type": "reachable", "value": true, "name": device.name ?? ""])
  }

  @objc private func aclDisconnected(_ n: IOBluetoothUserNotification, device: IOBluetoothDevice) {
    guard isTarget(device) else { return }
    emit(["type": "reachable", "value": false, "name": device.name ?? ""])
  }

  // MARK: RFCOMM

  private func connect() {
    guard channel == nil, !connecting else { return }
    guard let device = targetDevice() else {
      return status("failed", reason: "No paired Sony WH-1000XM headphones found. Pair them in System Settings → Bluetooth.")
    }
    // Don't try to open a link to headphones that are switched off; it just
    // burns seconds in the Bluetooth stack.
    guard device.isConnected() else {
      return status("failed", name: device.name, reason: "Headphones are off or out of range.")
    }
    connecting = true
    status("connecting", name: device.name)
    if openService(on: device) { return }
    if device.performSDPQuery(self) != kIOReturnSuccess {
      fail("SDP query failed to start")
    }
  }

  private func fail(_ reason: String) {
    connecting = false
    status("failed", reason: reason)
  }

  private func disconnect() {
    connecting = false
    let c = channel
    channel = nil
    c?.close()
  }

  @discardableResult
  private func openService(on device: IOBluetoothDevice) -> Bool {
    let uuid = IOBluetoothSDPUUID(bytes: Self.serviceUUID, length: Self.serviceUUID.count)
    guard let record = device.getServiceRecord(for: uuid) else { return false }
    var id: BluetoothRFCOMMChannelID = 0
    guard record.getRFCOMMChannelID(&id) == kIOReturnSuccess else {
      fail("Sony service has no RFCOMM channel")
      return true
    }
    rfcommChannelID = id
    var opened: IOBluetoothRFCOMMChannel?
    if device.openRFCOMMChannelAsync(&opened, withChannelID: id, delegate: self) != kIOReturnSuccess {
      fail("Could not open the control channel")
      return true
    }
    channel = opened
    return true
  }

  private func write(_ data: Data) {
    guard let channel = channel else { return }
    var bytes = [UInt8](data)
    _ = bytes.withUnsafeMutableBufferPointer { buf in
      channel.writeSync(buf.baseAddress, length: UInt16(buf.count))
    }
  }

  @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
    guard status == kIOReturnSuccess, let device = device, openService(on: device) else {
      return fail("Headphones don't advertise Sony's control service")
    }
  }
}

extension BluetoothPlugin: IOBluetoothRFCOMMChannelDelegate {
  func rfcommChannelOpenComplete(_ ch: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
    connecting = false
    if error != kIOReturnSuccess {
      channel = nil
      return status("failed", reason: "Couldn't open the control channel (\(error)).")
    }
    let dev = ch.getDevice()
    status("connected", name: dev?.name, details: [
      "Transport": "Classic Bluetooth · RFCOMM (SPP)",
      "Address": dev?.addressString ?? "—",
      "RFCOMM channel": String(rfcommChannelID),
      "Service UUID": "96CC203E-5068-46AD-B32D-E316F5E069BA",
      "Stack": "IOBluetooth (macOS)",
    ])
  }

  func rfcommChannelData(_ ch: IOBluetoothRFCOMMChannel!, data ptr: UnsafeMutableRawPointer!, length: Int) {
    emit(["type": "data", "bytes": FlutterStandardTypedData(bytes: Data(bytes: ptr, count: length))])
  }

  func rfcommChannelClosed(_ ch: IOBluetoothRFCOMMChannel!) {
    channel = nil
    status("disconnected")
  }
}
