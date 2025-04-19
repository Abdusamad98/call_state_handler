import Flutter
import UIKit

public class CallDetectorPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftCallDetectorPlugin()
        SwiftCallDetectorPlugin.register(with: registrar)
    }
}