package space.iscreation.vkpn

import android.content.Context
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import java.io.ByteArrayInputStream
import java.nio.charset.StandardCharsets

class WireGuardTunnelManager(
    context: Context,
    private val onLog: (String) -> Unit
) {
    private val backend = GoBackend(context)
    private val tunnel = AppTunnel()

    fun start(configText: String) {
        val config = Config.parse(ByteArrayInputStream(configText.toByteArray(StandardCharsets.UTF_8)))
        backend.setState(tunnel, Tunnel.State.UP, config)
    }

    fun stop() {
        backend.setState(tunnel, Tunnel.State.DOWN, null)
    }

    fun trafficStats(): Pair<Long, Long> {
        val stats = backend.getStatistics(tunnel)
        return Pair(stats.totalRx(), stats.totalTx())
    }

    inner class AppTunnel : Tunnel {
        override fun getName(): String = "unified_wg"

        override fun onStateChange(newState: Tunnel.State) {
            onLog("WireGuard state: $newState")
        }
    }
}
