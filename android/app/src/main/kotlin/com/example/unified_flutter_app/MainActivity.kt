package space.iscreation.vkpn

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import com.wireguard.android.backend.GoBackend
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPrepareResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null
    
    // Log file for external access via ADB
    private var logFile: File? = null
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)
    
    private fun getLogFile(): File {
        if (logFile == null) {
            // Use app's internal files directory (accessible via ADB run-as)
            val logDir = File(filesDir, "logs")
            if (!logDir.exists()) {
                logDir.mkdirs()
            }
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            logFile = File(logDir, "vkpn_log_$timestamp.txt")
        }
        return logFile!!
    }
    
    private fun writeLogToFile(message: String) {
        try {
            val file = getLogFile()
            val timestamp = dateFormat.format(Date())
            FileWriter(file, true).use { writer ->
                writer.appendLine("[$timestamp] $message")
            }
        } catch (e: Exception) {
            // Silently fail - don't crash the app for logging issues
        }
    }
    
    private val vpnToggleReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "space.iscreation.vkpn.TOGGLE_VPN") {
                // Send toggle event to Flutter
                methodChannel?.invokeMethod("onVpnToggleRequested", null)
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        VpnRuntime.init(applicationContext)
        VpnRuntime.setLogSink { log -> emitLog(log) }
        
        // Register broadcast receiver for VPN toggle
        val filter = IntentFilter("space.iscreation.vkpn.TOGGLE_VPN")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(vpnToggleReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(vpnToggleReceiver, filter)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(vpnToggleReceiver)
        } catch (e: Exception) {
            // Receiver might not be registered
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize method channel for VPN toggle
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "unified_vpn/methods")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "unified_vpn/methods")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBatteryOptimizationIgnored" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestDisableBatteryOptimization" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        } else {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "requestRuntimePermissions" -> {
                        requestRuntimePermissions(result)
                    }
                    "prepareVpn" -> {
                        val intent = GoBackend.VpnService.prepare(this)
                        if (intent == null) {
                            result.success(true)
                        } else {
                            pendingPrepareResult = result
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, 2001)
                        }
                    }
                    "start" -> {
                        Thread {
                            try {
                                val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                                val rewritten = (args["rewrittenConfig"] as? String).orEmpty()
                                val targetHost = (args["targetHost"] as? String).orEmpty()
                                val proxyPort = (args["proxyPort"] as? Number)?.toInt() ?: 56000
                                val vkCallLink = (args["vkCallLink"] as? String).orEmpty()
                                val localHost = (args["localEndpointHost"] as? String).orEmpty()
                                val localPort = (args["localEndpointPort"] as? Number)?.toInt() ?: 9000
                                val useUdp = (args["useUdp"] as? Boolean) ?: true
                                val useTurnMode = (args["useTurnMode"] as? Boolean) ?: true
                                val threads = (args["threads"] as? Number)?.toInt() ?: 8

                                val missing = mutableListOf<String>()
                                if (rewritten.isBlank()) missing.add("rewrittenConfig")
                                if (useTurnMode && targetHost.isBlank()) missing.add("targetHost")
                                if (useTurnMode && vkCallLink.isBlank()) missing.add("vkCallLink")
                                if (missing.isNotEmpty()) {
                                    throw IllegalArgumentException("Invalid runtime configuration: missing ${missing.joinToString(", ")}")
                                }

                                emitLog("Android: mode = ${if (useTurnMode) "WG+TURN" else "WG"}")
                                emitLog("Android: targetHost = $targetHost")
                                emitLog("Android: proxyPort = $proxyPort")
                                emitLog("Android: vkCallLink = [REDACTED]")
                                emitLog("Android: localEndpoint = $localHost:$localPort")
                                emitLog("Android: useUdp = $useUdp")
                                emitLog("Android: threads = $threads")
                                if (useTurnMode) {
                                    emitLog("Android: starting foreground service")
                                    emitLog("Android: starting vk-turn process")
                                }
                                // Start VPN with WireGuard + proxy
                                VpnRuntime.start(
                                    useTurnMode = useTurnMode,
                                    rewritten = rewritten,
                                    targetHost = targetHost,
                                    proxyPort = proxyPort,
                                    vkCallLink = vkCallLink,
                                    useUdp = useUdp,
                                    threads = threads,
                                    localEndpoint = "$localHost:$localPort"
                                )
                                // Update VPN active state for Quick Settings Tile
                                getSharedPreferences("vkpn_prefs", MODE_PRIVATE)
                                    .edit()
                                    .putBoolean("vpn_active", true)
                                    .apply()
                                emitLog("Android: unified tunnel started")
                                runOnUiThread { result.success(null) }
                            } catch (e: Throwable) {
                                val details = "${e::class.java.name}: ${e.message ?: "no message"}"
                                emitLog("START_FAILED: $details")
                                emitLog(e.stackTraceToString())
                                runOnUiThread { result.error("START_FAILED", details, e.stackTraceToString()) }
                            }
                        }.start()
                    }
                    "stop" -> {
                        try {
                            VpnRuntime.stop()
                            // Update VPN active state for Quick Settings Tile
                            getSharedPreferences("vkpn_prefs", MODE_PRIVATE)
                                .edit()
                                .putBoolean("vpn_active", false)
                                .apply()
                            emitLog("Android: unified tunnel stopped")
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("STOP_FAILED", e.message, null)
                        }
                    }
                    "status" -> result.success(VpnRuntime.getStatus())
                    "getVkTurnVersion" -> result.success(VpnRuntime.getVkTurnVersion())
                    "getVkTurnSource" -> result.success(VpnRuntime.getVkTurnSource())
                    "trafficStats" -> {
                        val (rx, tx) = VpnRuntime.trafficStats()
                        result.success(mapOf("rxBytes" to rx, "txBytes" to tx))
                    }
                    "listInstalledApps" -> {
                        Thread {
                            try {
                                val pm = packageManager
                                val intent = Intent(Intent.ACTION_MAIN).apply {
                                    addCategory(Intent.CATEGORY_LAUNCHER)
                                }
                                val activities = pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)
                                val seen = LinkedHashSet<String>()
                                val out = ArrayList<Map<String, String>>()
                                for (ri in activities) {
                                    val pkg = ri.activityInfo?.packageName ?: continue
                                    if (!seen.add(pkg)) continue
                                    val label = ri.loadLabel(pm).toString()
                                    out.add(mapOf("id" to pkg, "label" to label))
                                }
                                out.sortBy { it["label"] as String }
                                runOnUiThread { result.success(out) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("LIST_APPS_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }
                    "onVpnToggleRequested" -> {
                        // This is handled by Flutter through event channel
                        // Just acknowledge the request
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "unified_vpn/logs")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    emitLog("Android: log stream connected")
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    VpnRuntime.setLogSink(null)
                }
            })
    }

    private fun emitLog(message: String) {
        val sanitized = sanitizeLogMessage(message)
        // Write to file for ADB access
        writeLogToFile(sanitized)
        // Send to Flutter UI
        runOnUiThread {
            eventSink?.success(sanitized)
        }
    }

    private fun sanitizeLogMessage(message: String): String {
        var sanitized = message
        sanitized = sanitized.replace(Regex("(-peer\\s+)(\\S+)", RegexOption.IGNORE_CASE), "$1[REDACTED]")
        sanitized = sanitized.replace(Regex("(-vk-link\\s+)(\\S+)", RegexOption.IGNORE_CASE), "$1[REDACTED]")
        sanitized = sanitized.replace(Regex("https://vk\\.(?:ru|com)/call/join/\\S+", RegexOption.IGNORE_CASE), "[REDACTED]")
        val sensitiveKeys = listOf(
            "access_token",
            "anonymToken",
            "client_secret",
            "joinLink",
            "session_key",
            "vkCallLink",
            "vk_join_link"
        )
        for (key in sensitiveKeys) {
            sanitized = sanitized.replace(
                Regex("(${Regex.escape(key)}=)[^&\\s]+", RegexOption.IGNORE_CASE),
                "$1[REDACTED]"
            )
        }
        sanitized = sanitized.replace(
            Regex(
                "^(\\s*(?:PrivateKey|PresharedKey)\\s*=\\s*).*$",
                setOf(RegexOption.IGNORE_CASE, RegexOption.MULTILINE)
            ),
            "$1[REDACTED]"
        )
        return sanitized
    }

    private fun requestRuntimePermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            1001
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 1001) return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 2001) return
        val granted = GoBackend.VpnService.prepare(this) == null
        pendingPrepareResult?.success(granted)
        pendingPrepareResult = null
    }

}
