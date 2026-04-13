package space.iscreation.vkpn

import android.content.Context
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import kotlin.concurrent.thread

class VkTurnProcessManager(
    private val executableProvider: () -> String,
    private val onLog: (String) -> Unit
) {
    private var process: Process? = null

    fun start(targetHost: String, proxyPort: Int, vkCallLink: String, useUdp: Boolean, threads: Int, localEndpoint: String) {
        stop()
        val executable = executableProvider()
        val args = mutableListOf(
            executable,
            "-peer", "$targetHost:$proxyPort",
            "-vk-link", vkCallLink,
            "-listen", localEndpoint,
            "-n", threads.toString()
        )
        if (useUdp) {
            args.add("-udp")
        }
        onLog(
            "vk-turn cmd: $executable -peer $targetHost:$proxyPort -vk-link [REDACTED] " +
                "-listen $localEndpoint -n $threads${if (useUdp) " -udp" else ""}"
        )
        process = ProcessBuilder(args)
            .redirectErrorStream(true)
            .start()
        thread(start = true, isDaemon = true) {
            try {
                val reader = BufferedReader(InputStreamReader(process?.inputStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    onLog(line ?: "")
                }
            } catch (e: Exception) {
                onLog("vk-turn log reader error: ${e.message}")
            }
        }
    }

    fun stop() {
        process?.destroy()
        process = null
    }

    companion object {
        fun resolveExecutable(filesDir: File, nativeLibraryDir: String): String {
            val custom = File(filesDir, "custom_vkturn")
            if (custom.exists()) {
                custom.setExecutable(true)
                return custom.absolutePath
            }
            return "$nativeLibraryDir/libvkturn.so"
        }
        
        fun getVersion(context: Context, filesDir: File, nativeLibraryDir: String): String {
            // First check if custom binary exists
            val custom = File(filesDir, "custom_vkturn")
            if (custom.exists()) {
                return "custom"
            }
            
            // Check if bundled binary exists in native library dir
            val bundled = File(nativeLibraryDir, "libvkturn.so")
            if (bundled.exists()) {
                // Try to read version from assets
                return try {
                    val inputStream = context.assets.open("vkturn_version.txt")
                    val version = inputStream.bufferedReader().use { it.readText().trim() }
                    if (version.isNotEmpty()) {
                        return version.removePrefix("v")
                    }
                    "bundled"
                } catch (e: Exception) {
                    "bundled"
                }
            }
            
            return "unknown"
        }
        
        fun getExecutableSource(filesDir: File, nativeLibraryDir: String): String {
            val custom = File(filesDir, "custom_vkturn")
            return if (custom.exists()) "custom" else "bundled"
        }
    }
}
