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
    private var eventSink: EventChannel.EventSink? = null
    private val logHistory = Collections.synchronizedList(ArrayList<String>())
    private const val MAX_LOGS = 1500
    private var logFile: File? = null

    @Volatile
    private var isAppInForeground = true

    fun setAppInForeground(inForeground: Boolean) {
        isAppInForeground = inForeground
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

    @Synchronized
    fun setEventSink(sink: EventChannel.EventSink?) {
        mainHandler.post {
            eventSink = sink
        }
    }

    fun log(tag: String, message: String) {
        val timeStr = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val formatted = "[$timeStr][$tag] $message"
        android.util.Log.i("linkpc", formatted)

        synchronized(logHistory) {
            logHistory.add(formatted)
            if (logHistory.size > MAX_LOGS) {
                logHistory.removeAt(0)
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

        // Only stream live logs to Flutter if app is active in foreground
        if (isAppInForeground && eventSink != null) {
            mainHandler.post {
                try {
                    eventSink?.success(mapOf("type" to "log", "message" to formatted))
                } catch (_: Exception) {}
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
                        "total_up" to totalUp.toInt(),
                        "total_down" to totalDown.toInt()
                    )
                )
            } catch (_: Exception) {}
        }
    }

    fun getLogs(): List<String> {
        synchronized(logHistory) {
            return ArrayList(logHistory)
        }
    }

    fun clear() {
        synchronized(logHistory) {
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
