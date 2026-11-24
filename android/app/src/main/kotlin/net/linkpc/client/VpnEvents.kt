package net.linkpc.client

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors

object VpnEvents {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val fileExecutor = Executors.newSingleThreadExecutor()
    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    private val logLock = Any()
    private val logHistory = ArrayDeque<String>(1500)
    private const val MAX_LOGS = 1500
    private var logFile: File? = null

    @Volatile
    private var isAppInForeground = true

    private val pendingLogsLock = Any()
    private val pendingLogs = ArrayList<String>()
    @Volatile
    private var isFlushScheduled = false

    private val flushLogsRunnable = Runnable {
        isFlushScheduled = false
        if (!isAppInForeground || eventSink == null) {
            synchronized(pendingLogsLock) { pendingLogs.clear() }
            return@Runnable
        }

        val batch = synchronized(pendingLogsLock) {
            if (pendingLogs.isEmpty()) null
            else {
                val list = ArrayList(pendingLogs)
                pendingLogs.clear()
                list
            }
        } ?: return@Runnable

        try {
            if (batch.size == 1) {
                eventSink?.success(mapOf("type" to "log", "message" to batch[0]))
            } else {
                eventSink?.success(mapOf("type" to "logs", "messages" to batch))
            }
        } catch (_: Exception) {}
    }

    fun setAppInForeground(inForeground: Boolean) {
        isAppInForeground = inForeground
        if (!inForeground) {
            synchronized(pendingLogsLock) {
                pendingLogs.clear()
            }
            mainHandler.removeCallbacks(flushLogsRunnable)
            isFlushScheduled = false
        }
    }

    fun initLogFile(file: File) {
        logFile = file
        try {
            if (!file.parentFile?.exists()!!) {
                file.parentFile?.mkdirs()
            }
        } catch (_: Exception) {}
    }

    fun getLogFilePath(): String = logFile?.absolutePath ?: ""

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink == null) {
            synchronized(pendingLogsLock) { pendingLogs.clear() }
            mainHandler.removeCallbacks(flushLogsRunnable)
            isFlushScheduled = false
        }
    }

    fun log(tag: String, message: String) {
        val timeStr = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val formatted = "[$timeStr][$tag] $message"
        android.util.Log.i("linkpc", formatted)

        synchronized(logLock) {
            logHistory.addLast(formatted)
            if (logHistory.size > MAX_LOGS) {
                logHistory.removeFirst()
            }
        }

        // Write to log file asynchronously
        val targetFile = logFile
        if (targetFile != null) {
            fileExecutor.execute {
                try {
                    FileWriter(targetFile, true).use { writer ->
                        writer.append(formatted).append("\n")
                    }
                } catch (_: Exception) {}
            }
        }

        // Batch live logs to Flutter when app is in foreground
        if (isAppInForeground && eventSink != null) {
            synchronized(pendingLogsLock) {
                pendingLogs.add(formatted)
                if (!isFlushScheduled) {
                    isFlushScheduled = true
                    mainHandler.postDelayed(flushLogsRunnable, 150)
                }
            }
        }
    }

    fun sendStatus(status: String) {
        log("Status", "VPN state changed to: $status")
        mainHandler.post {
            try {
                eventSink?.success(mapOf("type" to "status", "state" to status))
            } catch (_: Exception) {}
        }
    }

    fun sendTraffic(upSpeed: Long, downSpeed: Long, totalUp: Long, totalDown: Long) {
        if (!isAppInForeground || eventSink == null) return
        mainHandler.post {
            try {
                eventSink?.success(
                    mapOf(
                        "type" to "traffic",
                        "up_speed" to upSpeed.toInt(),
                        "down_speed" to downSpeed.toInt(),
                        "total_up" to totalUp,
                        "total_down" to totalDown
                    )
                )
            } catch (_: Exception) {}
        }
    }

    fun getLogs(): List<String> {
        synchronized(logLock) {
            return ArrayList(logHistory)
        }
    }

    fun clear() {
        synchronized(logLock) {
            logHistory.clear()
        }
        val targetFile = logFile
        if (targetFile != null) {
            fileExecutor.execute {
                try {
                    if (targetFile.exists()) targetFile.writeText("")
                } catch (_: Exception) {}
            }
        }
        log("System", "Журнал диагностики очищен")
    }
}
