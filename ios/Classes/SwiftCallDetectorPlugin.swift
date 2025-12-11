import Flutter
import UIKit
import CallKit
import AVFoundation

public class SwiftCallDetectorPlugin: NSObject, FlutterPlugin {
    private var callObserver: CXCallObserver?
    private var audioSession: AVAudioSession?
    private var eventSink: FlutterEventSink?
    private var isMonitoringAudioSession = false
    private var lastCallState: (isActive: Bool, callType: String) = (false, "none")

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "com.example.call_detector/methods", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "com.example.call_detector/events", binaryMessenger: registrar.messenger())

        let instance = SwiftCallDetectorPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initializeCallObserver()
            result(nil)
        case "dispose":
            disposeCallObserver()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initializeCallObserver() {
        // Initialize CallKit observer for phone calls
        callObserver = CXCallObserver()
        callObserver?.setDelegate(self, queue: nil)
        
        // Initialize AVAudioSession monitoring for video calls
        setupAudioSessionMonitoring()
    }

    private func setupAudioSessionMonitoring() {
        audioSession = AVAudioSession.sharedInstance()
        
        // Set up audio session category to allow monitoring without interfering with app's audio
        // Use a passive category that won't interrupt other apps
        do {
            try audioSession?.setCategory(.ambient, mode: .default, options: [])
            try audioSession?.setActive(true, options: [])
        } catch {
            // If ambient fails, try without setting active to avoid interfering
            print("Note: Audio session setup may be limited: \(error)")
        }
        
        // Observe audio session interruptions and route changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
        
        // Check initial audio session state
        checkAudioSessionState()
        
        // Periodically check audio session state for video calls
        isMonitoringAudioSession = true
        checkAudioSessionPeriodically()
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began - another app is using audio (likely a video call)
            checkAudioSessionState()
        case .ended:
            // Interruption ended - check if call is still active
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    checkAudioSessionState()
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioSessionRouteChange(notification: Notification) {
        // Route change might indicate call state change
        checkAudioSessionState()
    }
    
    private func checkAudioSessionState() {
        guard let audioSession = audioSession else { return }
        
        // Check if another app is using audio (indicates potential video call)
        // Video calling apps will cause interruptions when they activate
        let isOtherAudioPlaying = audioSession.isOtherAudioPlaying
        
        // Check if secondary audio should be silenced (another app has priority)
        let shouldSilenceSecondaryAudio = audioSession.secondaryAudioShouldBeSilencedHint
        
        // Check current route - video calls often use specific routes
        let currentRoute = audioSession.currentRoute
        let hasInputRoute = !currentRoute.inputs.isEmpty
        let hasOutputRoute = !currentRoute.outputs.isEmpty
        
        // Determine if it's likely a video call based on audio session state
        // Video calling apps typically:
        // 1. Cause audio interruptions
        // 2. Use input/output routes (microphone + speaker)
        // 3. Silence secondary audio
        let isVideoCallActive = (isOtherAudioPlaying || shouldSilenceSecondaryAudio) && 
                               (hasInputRoute && hasOutputRoute)
        
        // Update call state if changed
        if isVideoCallActive != lastCallState.isActive || 
           (isVideoCallActive && lastCallState.callType != "videoCall") {
            lastCallState = (isVideoCallActive, "videoCall")
            if isVideoCallActive {
                sendCallState(isCallActive: true, callType: "videoCall")
            } else {
                // Check if there's still a phone call active
                checkPhoneCallState()
            }
        }
    }
    
    private func checkPhoneCallState() {
        // Check CallKit for phone calls
        guard let callObserver = callObserver else { return }
        let calls = callObserver.calls
        let hasActiveCall = calls.contains { !$0.hasEnded }
        
        if hasActiveCall != lastCallState.isActive || lastCallState.callType != "phoneCall" {
            lastCallState = (hasActiveCall, "phoneCall")
            sendCallState(isCallActive: hasActiveCall, callType: "phoneCall")
        } else if !hasActiveCall && !lastCallState.isActive {
            // No calls active
            lastCallState = (false, "none")
            sendCallState(isCallActive: false, callType: "none")
        }
    }
    
    private func checkAudioSessionPeriodically() {
        guard isMonitoringAudioSession else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAudioSessionState()
            self?.checkAudioSessionPeriodically()
        }
    }

    private func disposeCallObserver() {
        callObserver = nil
        isMonitoringAudioSession = false
        
        // Remove audio session observers
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: audioSession)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: audioSession)
        
        // Deactivate audio session
        do {
            try audioSession?.setActive(false)
        } catch {
            print("Error deactivating audio session: \(error)")
        }
        
        audioSession = nil
    }

    private func sendCallState(isCallActive: Bool, callType: String) {
        let callState: [String: Any] = [
            "isCallActive": isCallActive,
            "callType": callType
        ]

        DispatchQueue.main.async {
            self.eventSink?(callState)
        }
    }
}

extension SwiftCallDetectorPlugin: CXCallObserverDelegate {
    public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        let isCallActive = call.hasEnded == false
        
        // CallKit detects phone calls, not video calls from apps like Google Meet/Zoom
        // Video calls are detected via AVAudioSession monitoring
        if isCallActive {
            // This is a phone call
            lastCallState = (true, "phoneCall")
            sendCallState(isCallActive: true, callType: "phoneCall")
        } else {
            // Phone call ended, check if video call is still active
            checkAudioSessionState()
        }
    }
}

extension SwiftCallDetectorPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}