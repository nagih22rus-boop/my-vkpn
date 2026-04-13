package space.iscreation.vkpn

import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class VkpnTileService : TileService() {
    
    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }
    
    override fun onClick() {
        super.onClick()
        
        // Send broadcast to toggle VPN
        val intent = Intent(ACTION_TOGGLE_VPN).apply {
            setPackage("space.iscreation.vkpn")
        }
        sendBroadcast(intent)
    }
    
    private fun updateTile() {
        val tile = qsTile ?: return
        
        // Check if VPN is active by looking at shared preferences
        val prefs = getSharedPreferences("vkpn_prefs", MODE_PRIVATE)
        // STATE_ACTIVE = highlighted = VPN ON
        // STATE_INACTIVE = not highlighted = VPN OFF
        val isVpnActive = prefs.getBoolean("vpn_active", false)
        
        // Use INVERTED logic since user says it's backwards
        tile.state = if (isVpnActive) Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        tile.label = "VkPN"
        tile.updateTile()
    }
    
    companion object {
        const val ACTION_TOGGLE_VPN = "space.iscreation.vkpn.TOGGLE_VPN"
    }
}
