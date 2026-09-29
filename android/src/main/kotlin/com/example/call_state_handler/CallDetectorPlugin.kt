package com.example.call_state_handler

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Detects calls by polling the global [AudioManager] mode.
 *
 * - Cellular calls (MODE_IN_CALL, MODE_RINGTONE, ...) are reported as "phoneCall".
 * - MODE_IN_COMMUNICATION is reported as "videoCall" only when VoIP detection is
 *   enabled and the mode has been stable for [VOIP_DEBOUNCE_CHECKS] checks, because
 *   voice-message recorders and other apps briefly switch into this mode too.
 */
class CallDetectorPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var audioManager: AudioManager? = null
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private val audioModeChecker = Runnable { checkAudioMode() }
    private var isChecking = false
    private var voipDetectionEnabled = true
    private var communicationModeChecks = 0
    private var isCallActive = false
    private var callType = TYPE_NONE

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "com.example.call_detector/methods")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.example.call_detector/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                startMonitoring()
                result.success(null)
            }
            "dispose" -> {
                stopMonitoring()
                result.success(null)
            }
            "setVoipDetectionEnabled" -> {
                voipDetectionEnabled = call.argument<Boolean>("enabled") ?: true
                // Restart the debounce so a recorder that just released
                // MODE_IN_COMMUNICATION is not reported as a call on re-enable.
                communicationModeChecks = 0
                if (isChecking) checkAudioMode()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startMonitoring() {
        if (isChecking) return
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        isChecking = true
        handler.removeCallbacks(audioModeChecker)
        handler.post(audioModeChecker)
    }

    private fun stopMonitoring() {
        isChecking = false
        handler.removeCallbacks(audioModeChecker)
        audioManager = null
        communicationModeChecks = 0
        isCallActive = false
        callType = TYPE_NONE
    }

    private fun checkAudioMode() {
        handler.removeCallbacks(audioModeChecker)
        if (!isChecking) return
        val mode = audioManager?.mode ?: return

        communicationModeChecks = if (isCommunicationMode(mode)) communicationModeChecks + 1 else 0

        val newType = when {
            isPhoneCallMode(mode) -> TYPE_PHONE
            voipDetectionEnabled && communicationModeChecks >= VOIP_DEBOUNCE_CHECKS -> TYPE_VIDEO
            else -> TYPE_NONE
        }
        val newActive = newType != TYPE_NONE

        if (newActive != isCallActive || newType != callType) {
            isCallActive = newActive
            callType = newType
            sendState()
        }

        handler.postDelayed(audioModeChecker, CHECK_INTERVAL_MS)
    }

    private fun isPhoneCallMode(mode: Int): Boolean {
        if (mode == AudioManager.MODE_IN_CALL || mode == AudioManager.MODE_RINGTONE) return true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            mode == AudioManager.MODE_CALL_SCREENING
        ) return true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            mode == AudioManager.MODE_CALL_REDIRECT
        ) return true
        return false
    }

    private fun isCommunicationMode(mode: Int): Boolean {
        if (mode == AudioManager.MODE_IN_COMMUNICATION) return true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            mode == AudioManager.MODE_COMMUNICATION_REDIRECT
        ) return true
        return false
    }

    private fun sendState() {
        eventSink?.success(mapOf("isCallActive" to isCallActive, "callType" to callType))
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        sendState()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopMonitoring()
        eventSink = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    private companion object {
        const val TYPE_NONE = "none"
        const val TYPE_PHONE = "phoneCall"
        const val TYPE_VIDEO = "videoCall"
        const val CHECK_INTERVAL_MS = 1000L
        const val VOIP_DEBOUNCE_CHECKS = 3
    }
}
