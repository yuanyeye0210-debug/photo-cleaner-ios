package com.yuanye.photocleaner

import android.app.Activity
import android.app.AlertDialog
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.widget.Toast
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** 闪退记录：把最后一次没接住的异常写进文件，下次打开时弹窗显示，可复制发给开发者 */
object CrashLog {
    private const val FILE = "last_crash.txt"

    fun install(context: Context) {
        val app = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, e ->
            runCatching { File(app.filesDir, FILE).writeText(format(app, thread, e)) }
            previous?.uncaughtException(thread, e)
        }
    }

    private fun format(context: Context, thread: Thread, e: Throwable): String {
        val sw = StringWriter()
        e.printStackTrace(PrintWriter(sw))
        val version = runCatching {
            val pi = context.packageManager.getPackageInfo(context.packageName, 0)
            "${pi.versionName} (${if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else @Suppress("DEPRECATION") pi.versionCode.toLong()})"
        }.getOrDefault("?")
        return buildString {
            append("PhotoCleaner ").append(version).append('\n')
            append("时间 ").append(SimpleDateFormat("yyyy-MM-dd HH:mm:ss Z", Locale.US).format(Date())).append('\n')
            append("设备 ").append(Build.MANUFACTURER).append(' ').append(Build.MODEL)
                .append(" · Android ").append(Build.VERSION.RELEASE).append(" (API ").append(Build.VERSION.SDK_INT).append(")\n")
            append("线程 ").append(thread.name).append("\n\n")
            append(sw.toString().take(60_000))
        }
    }

    /** 上次闪退过：弹出记录（用系统对话框，不依赖 Compose，界面本身有问题也能显示） */
    fun showIfAny(activity: Activity) {
        val file = File(activity.filesDir, FILE)
        val text = runCatching { if (file.exists()) file.readText() else null }.getOrNull() ?: return
        runCatching { file.delete() }
        runCatching {
            AlertDialog.Builder(activity)
                .setTitle(R.string.crash_title)
                .setMessage(activity.getString(R.string.crash_message) + "\n\n" + text.take(4000))
                .setPositiveButton(R.string.crash_copy) { _, _ ->
                    val cm = activity.getSystemService(ClipboardManager::class.java)
                    cm?.setPrimaryClip(ClipData.newPlainText("PhotoCleaner crash", text))
                    Toast.makeText(activity, R.string.crash_copied, Toast.LENGTH_SHORT).show()
                }
                .setNegativeButton(R.string.crash_close, null)
                .show()
        }
    }
}
