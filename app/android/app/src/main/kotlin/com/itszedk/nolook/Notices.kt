package com.itszedk.nolook

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.app.Notification

/** notifications */
object Notices {
    private const val CHANNEL = "nolook"
    private const val BLOCKER_OFF = 1
    private var nextId = 100

    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        manager(context).createNotificationChannel(NotificationChannel(CHANNEL, "NoLook", NotificationManager.IMPORTANCE_DEFAULT))
    }

    fun allowed(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun show(context: Context, id: Int, title: String, text: String) {
        if (!allowed(context)) return
        ensureChannel(context)
        val open = PendingIntent.getActivity(
            context, id,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val n = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        runCatching { manager(context).notify(id, n) }
    }

    /** text comes translated from dart */
    fun post(context: Context, title: String, text: String) = show(context, nextId++, title, text)

    /** blocker got turned off */
    fun blockerOff(context: Context) {
        val turkce = Rules.turkish
        show(
            context, BLOCKER_OFF,
            if (turkce) "NoLook engelleyicisi kapalı" else "NoLook's blocker is off",
            if (turkce) "Sen yeniden açana kadar bu telefonda hiçbir şey engellenmez, NoLook'u açmak için dokun."
            else "Nothing gets blocked on this phone until it's back on, tap to open NoLook.",
        )
    }

    fun blockerBack(context: Context) = runCatching { manager(context).cancel(BLOCKER_OFF) }

    /**
     * Notification permission (13+). Asks once unless [force], then it asks again or opens settings.
     */
    fun ask(activity: Activity?, force: Boolean) {
        if (activity == null || allowed(activity) || Build.VERSION.SDK_INT < 33) return
        val prefs = activity.getSharedPreferences("nolook", Context.MODE_PRIVATE)
        val askedBefore = prefs.getBoolean("askedNotifications", false)
        if (askedBefore && !force) return
        prefs.edit().putBoolean("askedNotifications", true).apply()
        if (askedBefore && !activity.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) {
            activity.startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName),
            )
            return
        }
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
    }
}
