package space.iscreation.vkpn

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

/// Activity that handles APK installation when user clicks "Install" in update notification.
/// Shows the system APK install dialog.
class UpdateInstallActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val prefs = getSharedPreferences("vkpn_prefs", Context.MODE_PRIVATE)
        val apkPath = prefs.getString(UpdateWorker.UPDATE_PATH_KEY, null)

        if (apkPath == null) {
            finish()
            return
        }

        // Clear the pending update flag
        prefs.edit()
            .remove(UpdateWorker.UPDATE_FLAG_KEY)
            .remove(UpdateWorker.UPDATE_PATH_KEY)
            .remove(UpdateWorker.UPDATE_URL_KEY)
            .apply()

        // Launch system APK installer
        try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                File(apkPath)
            )

            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            }

            startActivity(installIntent)
        } catch (e: Exception) {
            // Fallback
            try {
                val uri = Uri.parse("file://$apkPath")
                val installIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(installIntent)
            } catch (e2: Exception) {
                val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        }

        finish()
    }
}
