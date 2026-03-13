package eu.kanade.tachiyomi.util.system

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import eu.kanade.tachiyomi.R
import eu.kanade.tachiyomi.ui.main.MainActivity
import tachiyomi.core.common.i18n.stringResource
import tachiyomi.i18n.MR
import tachiyomi.i18n.kmk.KMR

/**
 * Helper class for showing import notifications
 */
class ImportNotificationHelper(private val context: Context) {

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.stringResource(KMR.strings.notification_channel_import),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = context.stringResource(KMR.strings.notification_channel_import_description)
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Show notification for local import in progress
     */
    fun showLocalImportProgress(
        current: Int,
        total: Int,
        mangaName: String = "",
    ) {
        val title = context.stringResource(KMR.strings.local_import_background_notification_title)
        val text = if (mangaName.isNotBlank()) {
            "Importing $current/$total: $mangaName"
        } else {
            "Importing $current/$total..."
        }

        showProgressNotification(
            notificationId = LOCAL_IMPORT_NOTIFICATION_ID,
            title = title,
            text = text,
            progress = current,
            max = total,
        )
    }

    /**
     * Show notification when auto import starts
     */
    fun showAutoImportStart(total: Int) {
        val title = context.stringResource(KMR.strings.auto_import_background_notification_title)
        val text = context.stringResource(
            KMR.strings.auto_import_background_running,
            total,
        )

        showProgressNotification(
            notificationId = AUTO_IMPORT_NOTIFICATION_ID,
            title = title,
            text = text,
            progress = 0,
            max = total,
            ongoing = true,
        )
    }

    /**
     * Show notification for auto import progress
     */
    fun showAutoImportProgress(
        current: Int,
        total: Int,
        imported: Int,
        failed: Int,
    ) {
        val title = context.stringResource(KMR.strings.auto_import_background_notification_title)
        val text = "Importing $current/$total | ✓ $imported | ✗ $failed"

        showProgressNotification(
            notificationId = AUTO_IMPORT_NOTIFICATION_ID,
            title = title,
            text = text,
            progress = current,
            max = total,
            ongoing = true,
        )
    }

    /**
     * Show notification for completed local import
     */
    fun showLocalImportComplete(
        imported: Int,
        skipped: Int,
        errors: Int,
    ) {
        val title = context.stringResource(KMR.strings.local_import_background_notification_title)
        val text = context.stringResource(
            KMR.strings.local_import_background_notification_text,
            imported,
            skipped,
            errors,
        )

        showNotification(
            notificationId = LOCAL_IMPORT_NOTIFICATION_ID,
            title = title,
            text = text,
            category = NotificationCompat.CATEGORY_PROGRESS,
        )
    }

    /**
     * Show notification for completed auto import
     */
    fun showAutoImportComplete(
        imported: Int,
        failed: Int,
        errors: Int,
    ) {
        val title = context.stringResource(KMR.strings.auto_import_background_notification_title)
        val text = context.stringResource(
            KMR.strings.auto_import_background_notification_text,
            imported,
            failed,
            errors,
        )

        showNotification(
            notificationId = AUTO_IMPORT_NOTIFICATION_ID,
            title = title,
            text = text,
            category = NotificationCompat.CATEGORY_PROGRESS,
        )
    }

    /**
     * Show notification for import error
     */
    fun showImportError(
        title: String,
        message: String,
    ) {
        showNotification(
            notificationId = IMPORT_ERROR_NOTIFICATION_ID,
            title = title,
            text = message,
            category = NotificationCompat.CATEGORY_ERROR,
            priority = NotificationCompat.PRIORITY_HIGH,
        )
    }

    private fun showProgressNotification(
        notificationId: Int,
        title: String,
        text: String,
        progress: Int,
        max: Int,
        ongoing: Boolean = true,
    ) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_komikku)
            .setContentIntent(pendingIntent)
            .setOngoing(ongoing)
            .setOnlyAlertOnce(true)
            .setProgress(max, progress, false)
            .build()

        notificationManager.notify(notificationId, notification)
    }

    private fun showNotification(
        notificationId: Int,
        title: String,
        text: String,
        category: String,
        priority: Int = NotificationCompat.PRIORITY_LOW,
    ) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_komikku)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setCategory(category)
            .setPriority(priority)
            .setOnlyAlertOnce(true)
            .build()

        notificationManager.notify(notificationId, notification)
    }

    /**
     * Dismiss import notification
     */
    fun dismissNotification(notificationId: Int) {
        notificationManager.cancel(notificationId)
    }

    companion object {
        private const val CHANNEL_ID = "import_channel"
        private const val LOCAL_IMPORT_NOTIFICATION_ID = 10001
        private const val AUTO_IMPORT_NOTIFICATION_ID = 10002
        private const val IMPORT_ERROR_NOTIFICATION_ID = 10003
    }
}
