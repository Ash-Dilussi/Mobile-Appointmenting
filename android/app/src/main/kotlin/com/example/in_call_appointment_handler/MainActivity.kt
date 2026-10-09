package com.ashDilussi.bookly

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.CallLog as AndroidCallLog
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {

    // ── Channel names ───────────────────────────────────────────────────────
    private val CHANNEL              = "com.ashDilussi.bookly/call_detection"
    private val EVENT_CHANNEL        = "com.ashDilussi.bookly/call_events"
    private val RECORD_CHANNEL       = "com.ashDilussi.bookly/recording"
    private val RECORD_EVENT_CHANNEL = "com.ashDilussi.bookly/recording_events"

    // ── Channel references ──────────────────────────────────────────────────
    private var methodChannel:       MethodChannel? = null
    private var eventChannel:        EventChannel?  = null
    private var recordMethodChannel: MethodChannel? = null
    private var recordEventChannel:  EventChannel?  = null

    // ── Event sinks (must only be touched on the main thread) ───────────────
    private var eventSink:       EventChannel.EventSink? = null
    private var recordEventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Call receiver ───────────────────────────────────────────────────────
    private var callReceiver: BroadcastReceiver? = null
    private var lastEmittedCallDate: Long = 0L

    // ── Recording state ─────────────────────────────────────────────────────
    private var mediaRecorder:         MediaRecorder? = null
    private var isRecording:           Boolean = false
    private var currentRecordingPath:  String? = null
    private var recordingStartTime:    Long    = 0L

    // ════════════════════════════════════════════════════════════════════════
    // Flutter engine setup
    // ════════════════════════════════════════════════════════════════════════

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupCallDetectionChannel(flutterEngine)
        setupRecordingChannel(flutterEngine)
    }

    private fun setupCallDetectionChannel(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    // FIX #1: check READ_PHONE_STATE permission, not call state
                    "checkPermission" -> result.success(hasPhoneStatePermission())
                    "requestPermission" -> result.success(true) // Delegated to Flutter permission_handler
                    else -> result.notImplemented()
                }
            }
        }

        eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL
        ).also { ch ->
            ch.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerCallReceiver()
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterCallReceiver()
                }
            })
        }
    }

    private fun setupRecordingChannel(flutterEngine: FlutterEngine) {
        recordMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, RECORD_CHANNEL
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isFeatureEnabled" -> result.success(BuildConfig.DORMANT_CALL_INTEGRATION_ENABLED)
                    "checkPermission"  -> result.success(hasRecordingPermission())
                    // FIX #2: never stub permission — delegate to Flutter permission_handler
                    "requestPermission" -> result.success(hasRecordingPermission())
                    "startRecording"   -> result.success(startRecording())
                    "stopRecording"    -> result.success(stopRecording())
                    "isRecording"      -> result.success(isRecording)
                    "getRecordingPath" -> result.success(currentRecordingPath)
                    else               -> result.notImplemented()
                }
            }
        }

        recordEventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger, RECORD_EVENT_CHANNEL
        ).also { ch ->
            ch.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    recordEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    recordEventSink = null
                }
            })
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // Permission helpers
    // ════════════════════════════════════════════════════════════════════════

    // FIX #1 (continued): correct permission check
    private fun hasPhoneStatePermission(): Boolean =
        checkSelfPermission(Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED

    private fun hasRecordingPermission(): Boolean =
        BuildConfig.DORMANT_CALL_INTEGRATION_ENABLED &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    // ════════════════════════════════════════════════════════════════════════
    // Recording
    // ════════════════════════════════════════════════════════════════════════

    private fun startRecording(): String? {
        if (!BuildConfig.DORMANT_CALL_INTEGRATION_ENABLED) return null
        if (isRecording) return currentRecordingPath
        if (!hasRecordingPermission()) {
            emitRecordEvent("error", mapOf("message" to "RECORD_AUDIO permission not granted"))
            return null
        }

        return try {
            val recordingsDir = File(filesDir, "recordings").also { it.mkdirs() }
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val path = File(recordingsDir, "call_$timestamp.m4a").absolutePath

            mediaRecorder = buildMediaRecorder(path)
            isRecording           = true
            currentRecordingPath  = path
            recordingStartTime    = System.currentTimeMillis()

            emitRecordEvent("started", mapOf("path" to path, "duration" to 0))
            path
        } catch (e: Exception) {
            releaseMediaRecorder()
            emitRecordEvent("error", mapOf("message" to (e.message ?: "Failed to start recording")))
            null
        }
    }

    private fun stopRecording(): String? {
        if (!isRecording) return null

        val path = currentRecordingPath
        return try {
            mediaRecorder?.stop()
            val duration = (System.currentTimeMillis() - recordingStartTime) / 1000
            // FIX: clear state AFTER reading values
            releaseMediaRecorder()
            emitRecordEvent("stopped", mapOf("path" to path, "duration" to duration))
            path
        } catch (e: Exception) {
            releaseMediaRecorder()
            emitRecordEvent("error", mapOf("message" to (e.message ?: "Failed to stop recording")))
            null
        }
    }

    /**
     * FIX #5: Use VOICE_COMMUNICATION instead of MIC.
     * VOICE_COMMUNICATION routes through the same acoustic echo canceller used
     * during calls and, on many OEMs, captures the uplink + downlink mix where
     * the platform allows it. MIC captures only the microphone (one side).
     *
     * Note: Full two-sided call capture requires privileged/system-level access
     * on Android 9+. On non-rooted consumer devices you will capture at minimum
     * the microphone side. Disclose this behaviour to end-users.
     */
    private fun buildMediaRecorder(outputPath: String): MediaRecorder {
        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        return recorder.apply {
            setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION) // FIX #5
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioEncodingBitRate(128_000)
            setAudioSamplingRate(44_100)
            setOutputFile(outputPath)
            prepare()
            start()
        }
    }

    private fun releaseMediaRecorder() {
        try { mediaRecorder?.release() } catch (_: Exception) {}
        mediaRecorder        = null
        isRecording          = false
        currentRecordingPath = null
    }

    // ════════════════════════════════════════════════════════════════════════
    // Call receiver
    // ════════════════════════════════════════════════════════════════════════

    private fun registerCallReceiver() {
        callReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

                val state  = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: ""

                when (state) {
                    TelephonyManager.EXTRA_STATE_RINGING -> {
                        emitCallEvent("ringing", number)
                        emitRecordEvent("incoming", mapOf("number" to number))
                    }
                    TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                        emitCallEvent("offhook", number)
                        if (BuildConfig.DORMANT_CALL_INTEGRATION_ENABLED && !isRecording) {
                            startRecording()
                        }
                    }
                    TelephonyManager.EXTRA_STATE_IDLE -> {
                        emitCallEvent("idle", "")
                        if (BuildConfig.DORMANT_CALL_INTEGRATION_ENABLED && isRecording) {
                            stopRecording()
                        }
                        // Android's call-log provider is updated just after the
                        // phone-state idle broadcast. Read the authoritative
                        // completed row instead of reconstructing direction,
                        // number, and duration from partial state callbacks.
                        if (BuildConfig.DORMANT_CALL_INTEGRATION_ENABLED) {
                            mainHandler.postDelayed({ emitLatestCompletedCall() }, 750L)
                        }
                    }
                }
            }
        }

        val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)

        // FIX #3: RECEIVER_NOT_EXPORTED blocks system broadcasts on API 33+.
        // System broadcasts (sent by the platform) require RECEIVER_EXPORTED.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(callReceiver, filter, RECEIVER_EXPORTED) // FIX #3
        } else {
            registerReceiver(callReceiver, filter)
        }
    }

    private fun unregisterCallReceiver() {
        callReceiver?.let {
            try { unregisterReceiver(it) } catch (_: IllegalArgumentException) {}
            callReceiver = null
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // Event emission helpers (always post to main thread)
    // ════════════════════════════════════════════════════════════════════════

    private fun emitCallEvent(type: String, number: String) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to type, "number" to number))
        }
    }

    private fun emitLatestCompletedCall() {
        if (!BuildConfig.DORMANT_CALL_INTEGRATION_ENABLED) return
        if (checkSelfPermission(Manifest.permission.READ_CALL_LOG) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        try {
            val projection = arrayOf(
                AndroidCallLog.Calls.NUMBER,
                AndroidCallLog.Calls.TYPE,
                AndroidCallLog.Calls.DATE,
                AndroidCallLog.Calls.DURATION,
            )

            contentResolver.query(
                AndroidCallLog.Calls.CONTENT_URI,
                projection,
                null,
                null,
                "${AndroidCallLog.Calls.DATE} DESC",
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return

                val date = cursor.getLong(
                    cursor.getColumnIndexOrThrow(AndroidCallLog.Calls.DATE),
                )
                if (date <= lastEmittedCallDate) return

                val callType = cursor.getInt(
                    cursor.getColumnIndexOrThrow(AndroidCallLog.Calls.TYPE),
                )
                val direction = when (callType) {
                    AndroidCallLog.Calls.OUTGOING_TYPE -> "outgoing"
                    AndroidCallLog.Calls.MISSED_TYPE -> "missed"
                    else -> "incoming"
                }
                val number = cursor.getString(
                    cursor.getColumnIndexOrThrow(AndroidCallLog.Calls.NUMBER),
                ) ?: ""
                val duration = cursor.getLong(
                    cursor.getColumnIndexOrThrow(AndroidCallLog.Calls.DURATION),
                ).coerceAtLeast(0L)

                lastEmittedCallDate = date
                eventSink?.success(
                    mapOf(
                        "type" to "completed_call",
                        "number" to number,
                        "timestampMillis" to date,
                        "durationSeconds" to duration,
                        "direction" to direction,
                        "isMissed" to (callType == AndroidCallLog.Calls.MISSED_TYPE),
                    ),
                )
            }
        } catch (_: SecurityException) {
            // Permission can be revoked while the app is running. The Flutter
            // layer owns user-facing permission and recovery UX.
        } catch (_: Exception) {
            // A device/OEM may not expose the provider consistently. Keep the
            // state stream alive and wait for the next completed call.
        }
    }

    private fun emitRecordEvent(event: String, extra: Map<String, Any?> = emptyMap()) {
        mainHandler.post {
            recordEventSink?.success(mapOf("event" to event) + extra)
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // Lifecycle
    // ════════════════════════════════════════════════════════════════════════

    override fun onDestroy() {
        if (isRecording) stopRecording()
        unregisterCallReceiver()
        super.onDestroy()
    }
}
