package com.example.in_call_appointment_handler

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import android.telephony.PhoneStateListener
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
    private val CHANNEL = "com.example.in_call_appointment_handler/call_detection"
    private val EVENT_CHANNEL = "com.example.in_call_appointment_handler/call_events"
    private val RECORD_CHANNEL = "com.example.in_call_appointment_handler/recording"
    private val RECORD_EVENT_CHANNEL = "com.example.in_call_appointment_handler/recording_events"

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var recordMethodChannel: MethodChannel? = null
    private var recordEventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var recordEventSink: EventChannel.EventSink? = null
    private var callReceiver: BroadcastReceiver? = null

    // Call Recording
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    private var currentRecordingPath: String? = null
    private var recordingStartTime: Long = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Call Detection Channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    result.success(hasCallPermission())
                }
                "requestPermission" -> {
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                registerCallReceiver()
            }

            override fun onCancel(arguments: Any?) {
                unregisterCallReceiver()
            }
        })

        // Recording Channel
        recordMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORD_CHANNEL)
        recordMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    result.success(hasRecordingPermission())
                }
                "requestPermission" -> {
                    result.success(requestRecordingPermission())
                }
                "startRecording" -> {
                    val path = startRecording()
                    result.success(path)
                }
                "stopRecording" -> {
                    val path = stopRecording()
                    result.success(path)
                }
                "isRecording" -> {
                    result.success(isRecording)
                }
                "getRecordingPath" -> {
                    result.success(currentRecordingPath)
                }
                else -> result.notImplemented()
            }
        }

        recordEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, RECORD_EVENT_CHANNEL)
        recordEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                recordEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                recordEventSink = null
            }
        })
    }

    private fun hasCallPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            tm.callState != TelephonyManager.CALL_STATE_IDLE
        } else {
            true
        }
    }

    private fun hasRecordingPermission(): Boolean {
        return checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun requestRecordingPermission(): Boolean {
        // In real implementation, would request permission via Activity
        // For now, assume permission is granted via permission_handler package
        return true
    }

    private fun startRecording(): String? {
        if (isRecording) return currentRecordingPath

        try {
            val recordingsDir = File(filesDir, "recordings")
            if (!recordingsDir.exists()) {
                recordingsDir.mkdirs()
            }

            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val fileName = "call_$timestamp.m4a"
            val file = File(recordingsDir, fileName)
            val path = file.absolutePath

            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            mediaRecorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128000)
                setAudioSamplingRate(44100)
                setOutputFile(path)
                prepare()
                start()
            }

            isRecording = true
            currentRecordingPath = path
            recordingStartTime = System.currentTimeMillis()

            recordEventSink?.success(mapOf(
                "event" to "started",
                "path" to path,
                "duration" to 0
            ))

            return path
        } catch (e: Exception) {
            e.printStackTrace()
            recordEventSink?.success(mapOf(
                "event" to "error",
                "message" to (e.message ?: "Failed to start recording")
            ))
            return null
        }
    }

    private fun stopRecording(): String? {
        if (!isRecording) return null

        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            isRecording = false

            val duration = (System.currentTimeMillis() - recordingStartTime) / 1000
            val path = currentRecordingPath

            recordEventSink?.success(mapOf(
                "event" to "stopped",
                "path" to path,
                "duration" to duration
            ))

            return path
        } catch (e: Exception) {
            e.printStackTrace()
            recordEventSink?.success(mapOf(
                "event" to "error",
                "message" to (e.message ?: "Failed to stop recording")
            ))
            return null
        }
    }

    private fun registerCallReceiver() {
        callReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "android.intent.action.PHONE_STATE") {
                    val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                    val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

                    when (state) {
                        TelephonyManager.EXTRA_STATE_RINGING -> {
                            eventSink?.success(mapOf(
                                "type" to "ringing",
                                "number" to (number ?: "Unknown")
                            ))
                            // Notify that recording will be enabled
                            recordEventSink?.success(mapOf(
                                "event" to "incoming",
                                "number" to (number ?: "Unknown")
                            ))
                        }
                        TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                            eventSink?.success(mapOf(
                                "type" to "offhook",
                                "number" to (number ?: "")
                            ))
                            // Auto-start recording when call is answered
                            if (!isRecording) {
                                startRecording()
                            }
                        }
                        TelephonyManager.EXTRA_STATE_IDLE -> {
                            eventSink?.success(mapOf(
                                "type" to "idle",
                                "number" to ""
                            ))
                            // Stop recording when call ends
                            if (isRecording) {
                                stopRecording()
                            }
                        }
                    }
                }
            }
        }

        val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(callReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(callReceiver, filter)
        }
    }

    private fun unregisterCallReceiver() {
        callReceiver?.let {
            unregisterReceiver(it)
            callReceiver = null
        }
    }

    override fun onDestroy() {
        // Stop recording if active
        if (isRecording) {
            stopRecording()
        }
        unregisterCallReceiver()
        super.onDestroy()
    }
}