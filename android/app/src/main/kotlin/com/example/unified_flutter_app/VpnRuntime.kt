package space.iscreation.vkpn

import android.content.Context
import android.content.Intent

object VpnRuntime {
    private var initialized = false
    private lateinit var wireGuardManager: WireGuardTunnelManager
    private lateinit var vkTurnManager: VkTurnProcessManager
    private var appContext: Context? = null
    private var logSink: ((String) -> Unit)? = null
    private var status: String = "disconnected"

    @Synchronized
    fun init(context: Context) {
        if (initialized) return
        appContext = context.applicationContext
        wireGuardManager = WireGuardTunnelManager(context.applicationContext) { msg -> logSink?.invoke(msg) }
        vkTurnManager = VkTurnProcessManager(
            executableProvider = {
                val ctx = context.applicationContext
                VkTurnProcessManager.resolveExecutable(ctx.filesDir, ctx.applicationInfo.nativeLibraryDir)
            },
            onLog = { msg -> logSink?.invoke(msg) }
        )
        initialized = true
    }

    @Synchronized
    fun setLogSink(sink: ((String) -> Unit)?) {
        logSink = sink
    }

    @Synchronized
    fun start(
        useTurnMode: Boolean,
        rewritten: String,
        targetHost: String,
        proxyPort: Int,
        vkCallLink: String,
        useUdp: Boolean,
        threads: Int,
        localEndpoint: String
    ) {
        val ctx = appContext ?: throw IllegalStateException("VpnRuntime is not initialized")
        if (useTurnMode) {
            ctx.startService(Intent(ctx, ProxyForegroundService::class.java))
            vkTurnManager.start(
                targetHost = targetHost,
                proxyPort = proxyPort,
                vkCallLink = vkCallLink,
                useUdp = useUdp,
                threads = threads,
                localEndpoint = localEndpoint
            )
        }
        wireGuardManager.start(rewritten)
        status = "connected"
    }

    // Start only proxy without VPN (for testing)
    @Synchronized
    fun startProxyOnly(
        targetHost: String,
        proxyPort: Int,
        vkCallLink: String,
        useUdp: Boolean,
        threads: Int,
        localEndpoint: String = "127.0.0.1:9000"
    ) {
        val ctx = appContext ?: throw IllegalStateException("VpnRuntime is not initialized")
        ctx.startService(Intent(ctx, ProxyForegroundService::class.java))
        vkTurnManager.start(
            targetHost = targetHost,
            proxyPort = proxyPort,
            vkCallLink = vkCallLink,
            useUdp = useUdp,
            threads = threads,
            localEndpoint = localEndpoint
        )
        status = "proxy_only"
    }

    @Synchronized
    fun stop() {
        val ctx = appContext ?: throw IllegalStateException("VpnRuntime is not initialized")
        wireGuardManager.stop()
        vkTurnManager.stop()
        ctx.stopService(Intent(ctx, ProxyForegroundService::class.java))
        status = "disconnected"
    }

    @Synchronized
    fun trafficStats(): Pair<Long, Long> {
        return try {
            wireGuardManager.trafficStats()
        } catch (_: Throwable) {
            Pair(0L, 0L)
        }
    }

    @Synchronized
    fun getStatus(): String = status

    fun getVkTurnVersion(): String {
        val ctx = appContext ?: return "unknown"
        return VkTurnProcessManager.getVersion(ctx, ctx.filesDir, ctx.applicationInfo.nativeLibraryDir)
    }

    fun getVkTurnSource(): String {
        val ctx = appContext ?: return "unknown"
        return VkTurnProcessManager.getExecutableSource(ctx.filesDir, ctx.applicationInfo.nativeLibraryDir)
    }
}
