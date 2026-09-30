import Cocoa
import FlutterMacOS

/// Non-Bluetooth OS integrations for the Dart side (channel `flsony/system`).
enum SystemPlugin {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "flsony/system", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "pauseMedia": result(MediaRemote.pause())
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Sends a system-wide Pause through Apple's private MediaRemote framework,
/// loaded at runtime (same approach as the sony-connect-osx reference).
/// kMRPause is idempotent: unlike the Play/Pause media key it never starts
/// playback when nothing is playing.
private enum MediaRemote {
  private typealias SendCommand = @convention(c) (Int, AnyObject?) -> Bool

  private static let sendCommand: SendCommand? = {
    let url = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
    guard let bundle = CFBundleCreate(kCFAllocatorDefault, url as CFURL),
          let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString)
    else { return nil }
    return unsafeBitCast(ptr, to: SendCommand.self)
  }()

  static func pause() -> Bool {
    let kMRPause = 1
    return sendCommand?(kMRPause, nil) ?? false
  }
}
