import Cocoa
import FlutterMacOS

/// Non-Bluetooth OS integrations for the Dart side (channel `flsony/system`).
enum SystemPlugin {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "flsony/system", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "pauseMedia":
        let viaMediaRemote = MediaRemote.pause()
        MediaPlayers.pauseRunning { paused in result(paused || viaMediaRemote) }
      case "prepareMediaPause":
        MediaPlayers.requestAccess()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Pauses scriptable players over Apple Events. Only players that are already
/// running are addressed, so none get launched, and "pause" never starts
/// playback. Covers what MediaRemote no longer does for third-party apps.
private enum MediaPlayers {
  // Keep in sync with com.apple.security.temporary-exception.apple-events
  // in the entitlements files.
  static let bundleIDs = ["com.spotify.client", "com.apple.Music", "com.apple.TV"]

  private static var running: [String] {
    bundleIDs.filter { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }
  }

  /// Apple Events block until the user answers the automation prompt, so
  /// they run off the main thread (which Flutter's UI shares).
  static func pauseRunning(completion: @escaping (Bool) -> Void) {
    let targets = running
    DispatchQueue.global(qos: .userInitiated).async {
      var paused = false
      for id in targets {
        var error: NSDictionary?
        NSAppleScript(source: "tell application id \"\(id)\" to pause")?.executeAndReturnError(&error)
        if error == nil { paused = true }
      }
      DispatchQueue.main.async { completion(paused) }
    }
  }

  /// Shows the "control <player>" permission prompt now, when the user turns
  /// the feature on, rather than at power-off time.
  static func requestAccess() {
    for id in running {
      let target = NSAppleEventDescriptor(bundleIdentifier: id)
      DispatchQueue.global(qos: .userInitiated).async {
        _ = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
      }
    }
  }
}

/// Sends a system-wide Pause through Apple's private MediaRemote framework,
/// loaded at runtime (same approach as the sony-connect-osx reference).
/// kMRPause is idempotent: unlike the Play/Pause media key it never starts
/// playback when nothing is playing. macOS 15.4+ ignores it for non-Apple
/// apps; MediaPlayers covers that case.
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
