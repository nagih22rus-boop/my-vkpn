package space.iscreation.vkpn

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.*
import kotlinx.coroutines.*
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class UpdateWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        const val WORK_NAME = "vkpn_update_check"
        const val CHANNEL_ID = "app_update_channel"
        const val NOTIFICATION_ID = 102
        const val UPDATE_FLAG_KEY = "pending_update_version"
        const val UPDATE_PATH_KEY = "pending_update_path"
        const val UPDATE_URL_KEY = "pending_update_url"
        const val APK_REPO = "nagih22rus-boop/my-vkpn"

        fun getCurrentAppVersion(context: Context): String {
            return try {
                context.assets.open("app_version.txt").bufferedReader().use { it.readText().trim() }
            } catch (e: Exception) {
                "1.0.0"
            }
        }

        fun enqueue(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = PeriodicWorkRequestBuilder<UpdateWorker>(
                6, TimeUnit.HOURS
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }

    override suspend fun doWork(): Result {
        return try {
            // Check if update already pending
            val prefs = applicationContext.getSharedPreferences("vkpn_prefs", Context.MODE_PRIVATE)
            if (prefs.getString(UPDATE_FLAG_KEY, null) != null) {
                // Already has pending update
                return Result.success()
            }

            // Check GitHub for new version
            val latestVersion = fetchLatestVersion()
            if (latestVersion == null) {
                return Result.success()
            }

            if (compareVersions(latestVersion, getCurrentAppVersion(applicationContext)) <= 0) {
                return Result.success()
            }

            // Find APK download URL
            val apkUrl = fetchApkUrl(latestVersion)
            if (apkUrl == null) {
                return Result.success()
            }

            // Download APK
            val apkFile = downloadApk(apkUrl, latestVersion)
            if (apkFile != null) {
                // Save pending update info
                prefs.edit()
                    .putString(UPDATE_FLAG_KEY, latestVersion)
                    .putString(UPDATE_PATH_KEY, apkFile.absolutePath)
                    .putString(UPDATE_URL_KEY, apkUrl)
                    .apply()

                // Show notification
                showUpdateNotification(latestVersion)
            }

            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    private fun fetchLatestVersion(): String? {
        return try {
            val url = URL("https://api.github.com/repos/$APK_REPO/releases/latest")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.setRequestProperty("Accept", "application/vnd.github+json")
            conn.connectTimeout = 10000
            conn.readTimeout = 10000

            if (conn.responseCode != 200) return null

            val response = conn.inputStream.bufferedReader().readText()
            conn.disconnect()

            val tagMatch = Regex(""""tag_name"\s*:\s*"([^"]+)"""").find(response)
            val tag = tagMatch?.groupValues?.get(1) ?: return null
            tag.removePrefix("v")
        } catch (e: Exception) {
            null
        }
    }

    private fun fetchApkUrl(version: String): String? {
        return try {
            val url = URL("https://api.github.com/repos/$APK_REPO/releases/latest")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.setRequestProperty("Accept", "application/vnd.github+json")
            conn.connectTimeout = 10000
            conn.readTimeout = 10000

            if (conn.responseCode != 200) return null

            val response = conn.inputStream.bufferedReader().readText()
            conn.disconnect()

            // Find APK asset
            val assetsMatch = Regex(""""assets"\s*:\s*\[([\s\S]*?)\]""").find(response)
            val assets = assetsMatch?.groupValues?.get(1) ?: return null

            val browserUrl = Regex(""""browser_download_url"\s*:\s*""([^"]+\.apk)"""").find(assets)
            browserUrl?.groupValues?.get(1)
        } catch (e: Exception) {
            null
        }
    }

    private fun downloadApk(url: String, version: String): File? {
        return try {
            val file = File(applicationContext.cacheDir, "vkpn_update_$version.apk")
            if (file.exists()) return file

            val conn = URL(url).openConnection() as HttpURLConnection
            conn.connectTimeout = 60000
            conn.readTimeout = 60000

            conn.inputStream.use { input ->
                file.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            conn.disconnect()

            file
        } catch (e: Exception) {
            null
        }
    }

    private fun showUpdateNotification(version: String) {
        val notificationManager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager

        // Create notification channel for Android O+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Обновления",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Уведомления о доступных обновлениях VkPN"
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Intent to open app
        val openIntent = applicationContext.packageManager
            .getLaunchIntentForPackage(applicationContext.packageName)
        val pendingOpenIntent = PendingIntent.getActivity(
            applicationContext,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Intent to install APK
        val installIntent = Intent(applicationContext, UpdateInstallActivity::class.java)
        val pendingInstallIntent = PendingIntent.getActivity(
            applicationContext,
            1,
            installIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setContentTitle("Доступно обновление VkPN")
            .setContentText("Версия $version готова к установке. Нажмите для обновления.")
            .setSmallIcon(android.R.drawable.ic_menu_upload)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingOpenIntent)
            .setAutoCancel(true)
            .addAction(
                android.R.drawable.ic_menu_upload,
                "Установить",
                pendingInstallIntent
            )
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun compareVersions(v1: String, v2: String): Int {
        val parts1 = v1.split('.').map { it.toIntOrNull() ?: 0 }
        val parts2 = v2.split('.').map { it.toIntOrNull() ?: 0 }
        val maxLen = maxOf(parts1.size, parts2.size)

        for (i in 0 until maxLen) {
            val p1 = parts1.getOrElse(i) { 0 }
            val p2 = parts2.getOrElse(i) { 0 }
            if (p1 != p2) return p1.compareTo(p2)
        }
        return 0
    }
}
