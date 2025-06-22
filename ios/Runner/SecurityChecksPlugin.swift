import Flutter
import UIKit

@objc public class SecurityChecksPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.nidhi_rakshak/security_checks", binaryMessenger: registrar.messenger())
    let instance = SecurityChecksPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isDebuggerAttached":
      result(isDebuggerAttached())
    case "hasDeveloperProfile":
      result(hasDeveloperProfile())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Check if a debugger is currently attached to the app
  private func isDebuggerAttached() -> Bool {
    var info = kinfo_proc()
    var mib : [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    var size = MemoryLayout<kinfo_proc>.stride
    let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
    assert(junk == 0, "sysctl failed")
    return (info.kp_proc.p_flag & P_TRACED) != 0
  }

  // Check if app is running with a developer profile
  private func hasDeveloperProfile() -> Bool {
    #if DEBUG
      return true
    #else
      // In a real implementation, you would check for developer certificates and profiles
      // This is a basic placeholder
      let path = Bundle.main.appStoreReceiptURL?.path
      return path?.contains("sandboxReceipt") ?? false
    #endif
  }
}
