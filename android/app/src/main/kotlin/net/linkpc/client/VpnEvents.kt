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
    private var lastUpSpeed: Long = 0L
    private var lastDownSpeed: Long = 0L
    private var lastTotalUp: Long = 0L
    private var lastTotalDown: Long = 0L
    @Volatile
    private var lastTrafficDispatchTime = 0L

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
        } else {
            if (lastTotalUp > 0 || lastTotalDown > 0) {
                lastTrafficDispatchTime = 0L
                sendTraffic(lastUpSpeed, lastDownSpeed, lastTotalUp, lastTotalDown)
            }
        }
    }

    fun initLogFile(file: File) {
        logFile = file
        try {
            file.parentFile?.mkdirs()
            // Asynchronously load recent history from disk if memory buffer is empty
            if (file.exists() && file.length() > 0) {
                fileExecutor.execute {
                    loadLogsFromFile(file)
                }
            }
        } catch (_: Exception) {}
    }

    private fun loadLogsFromFile(file: File) {
        synchronized(logLock) {
            if (logHistory.isNotEmpty()) return
            try {
                val lines = file.readLines()
                val start = if (lines.size > MAX_LOGS) lines.size - MAX_LOGS else 0
                for (i in start until lines.size) {
                    val l = lines[i].trim()
                    if (l.isNotEmpty()) {
                        logHistory.addLast(l)
                    }
                }
            } catch (_: Exception) {}
        }
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

    private val timeFormat = object : ThreadLocal<SimpleDateFormat>() {
        override fun initialValue(): SimpleDateFormat {
            return SimpleDateFormat("HH:mm:ss.SSS", Locale.US)
        }
    }
    private var writeCounter = 0

    fun log(tag: String, message: String) {
        val timeStr = timeFormat.get()?.format(Date()) ?: ""
        val formatted = "[$timeStr][$tag] $message"
        android.util.Log.i("linkpc", formatted)

        synchronized(logLock) {
            logHistory.addLast(formatted)
            if (logHistory.size > MAX_LOGS) {
                logHistory.removeFirst()
            }
        }

        // Write to log file asynchronously with size guard (max 2MB)
        val targetFile = logFile
        if (targetFile != null) {
            fileExecutor.execute {
                try {
                    FileWriter(targetFile, true).use { writer ->
                        writer.append(formatted).append("\n")
                    }
                    writeCounter++
                    if (writeCounter % 200 == 0 && targetFile.length() > 2 * 1024 * 1024) {
                        pruneLogFile(targetFile)
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

    private fun pruneLogFile(file: File) {
        try {
            val lines = file.readLines()
            if (lines.size > MAX_LOGS) {
                val kept = lines.subList(lines.size - MAX_LOGS / 2, lines.size)
                file.writeText(kept.joinToString("\n") + "\n")
            }
        } catch (_: Exception) {}
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
        lastUpSpeed = upSpeed
        lastDownSpeed = downSpeed
        lastTotalUp = totalUp
        lastTotalDown = totalDown
        if (!isAppInForeground || eventSink == null) return

        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastTrafficDispatchTime < 800) return
        lastTrafficDispatchTime = now

        mainHandler.post {
            try {
                eventSink?.success(
                    mapOf(
                        "type" to "traffic",
                        "up_speed" to upSpeed,
                        "down_speed" to downSpeed,
                        "total_up" to totalUp,
                        "total_down" to totalDown
                    )
                )
            } catch (_: Exception) {}
        }
    }

    fun getLogs(): List<String> {
        synchronized(logLock) {
            if (logHistory.isEmpty()) {
                val file = logFile
                if (file != null && file.exists() && file.length() > 0) {
                    try {
                        val lines = file.readLines()
                        val start = if (lines.size > MAX_LOGS) lines.size - MAX_LOGS else 0
                        for (i in start until lines.size) {
                            val l = lines[i].trim()
                            if (l.isNotEmpty()) {
                                logHistory.addLast(l)
                            }
                        }
                    } catch (_: Exception) {}
                }
            }
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
