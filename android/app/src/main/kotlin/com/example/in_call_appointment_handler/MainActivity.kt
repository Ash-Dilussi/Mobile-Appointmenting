package com.example.in_call_appointment_handler

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.in_call_appointment_handler/call_detection"
    private val EVENT_CHANNEL = "com.example.in_call_appointment_handler/call_events"

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var callReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
    }

    private fun hasCallPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            tm.callState != TelephonyManager.CALL_STATE_IDLE
        } else {
            true
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
                        }
                        TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                            eventSink?.success(mapOf(
                                "type" to "offhook",
                                "number" to (number ?: "")
                            ))
                        }
                        TelephonyManager.EXTRA_STATE_IDLE -> {
                            eventSink?.success(mapOf(
                                "type" to "idle",
                                "number" to ""
                            ))
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
        unregisterCallReceiver()
        super.onDestroy()
    }
}
