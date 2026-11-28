package echo.music.iad1tya.echomusic

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import echo.music.iad1tya.R

object UpdateNotificationHelper {
  private const val CHANNEL_ID = "updates"
  private const val NOTIFICATION_ID = 1001

  fun showUpdateNotification(context: Context, versionName: String) {
    val nm = context.getSystemService(NotificationManager::class.java)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel =
        NotificationChannel(
          CHANNEL_ID,
          context.getString(R.string.app_updates_title),
          NotificationManager.IMPORTANCE_HIGH,
        )
      nm.createNotificationChannel(channel)
    }

    val cleanTag = versionName.trim()
    val downloadPageUrl =
      if (cleanTag.isNotBlank()) {
        "https://github.com/Roshangamerz/Omni-player/releases/tag/$cleanTag"
      } else {
        "https://github.com/Roshangamerz/Omni-player/releases/latest"
      }
    val intent =
      Intent(Intent.ACTION_VIEW, downloadPageUrl.toUri()).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
      }

    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    val pending = PendingIntent.getActivity(context, NOTIFICATION_ID, intent, flags)

    val notif =
      NotificationCompat.Builder(context, CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_launcher_nobg)
        .setContentTitle(context.getString(R.string.update_available_title))
        .setContentText("Omni Player $versionName is ready — Tap to download")
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        .setContentIntent(pending)
        .setAutoCancel(true)
        .build()

    if (
      Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
          PackageManager.PERMISSION_GRANTED
    ) {
      NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notif)
    }
  }
}
