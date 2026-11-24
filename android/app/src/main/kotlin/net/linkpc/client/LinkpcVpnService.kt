package net.linkpc.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.Process
import android.system.OsConstants
import android.util.Log
import io.nekohasekai.libbox.*
import java.io.File
import java.net.InetSocketAddress
import java.net.NetworkInterface

class StringArray(private val list: List<String>) : StringIterator {
    private var idx = 0
    override fun hasNext(): Boolean = idx < list.size
    override fun next(): String = list[idx++]
    override fun len(): Int = list.size
}

class InterfaceArray(private val list: List<io.nekohasekai.libbox.NetworkInterface>) : NetworkInterfaceIterator {
    private var idx = 0
    override fun hasNext(): Boolean = idx < list.size
    override fun next(): io.nekohasekai.libbox.NetworkInterface = list[idx++]
}

class LinkpcVpnService : VpnService(), PlatformInterface, CommandServerHandler {
    companion object {
        const val TAG = "LinkpcVpnService"
        const val ACTION_START = "net.linkpc.client.START"
        const val ACTION_STOP = "net.linkpc.client.STOP"
        const val EXTRA_CONFIG = "extra_config"
        const val CHANNEL_ID = "linkpc_vpn_channel"
        const val NOTIFICATION_ID = 1001

        @Volatile
        var isRunning = false
            private set

        @Volatile
        private var isLibboxSetup = false
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var vpnInterface: ParcelFileDescriptor? = null
    private var commandServer: CommandServer? = null
    private var commandClient: CommandClient? = null
    private var defaultInterfaceListener: InterfaceUpdateListener? = null
    private var connectivityManager: ConnectivityManager? = null
    private var networkHandlerThread: android.os.HandlerThread? = null
    @Volatile
    private var lastTargetNet: Network? = null
    @Volatile
    private var lastInterfaceName: String? = null
    @Volatile
    private var lastInterfaceIndex: Int = -1
    @Volatile
    private var lastIsExpensive: Boolean = false
    @Volatile
    private var lastIsConstrained: Boolean = false

    // Cache UID package names to eliminate repetitive synchronous Binder IPC to PackageManagerService
    private val uidPackageCache = java.util.concurrent.ConcurrentHashMap<Int, Pair<String, List<String>>>()

    // Cache network interfaces for 1.5 seconds to prevent kernel ioctl thrashing
    @Volatile
    private var cachedInterfacesList: List<io.nekohasekai.libbox.NetworkInterface>? = null
    @Volatile
    private var lastInterfacesTime: Long = 0L

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            cachedInterfacesList = null
            VpnEvents.log("Network", "Физическая сеть доступна: $network")
            updateDefaultInterface(network)
        }
        override fun onLost(network: Network) {
            cachedInterfacesList = null
            VpnEvents.log("Network", "Физическая сеть потеряна: $network")
            updateDefaultInterface()
        }
        override fun onLinkPropertiesChanged(network: Network, linkProperties: android.net.LinkProperties) {
            cachedInterfacesList = null
            updateDefaultInterface(network)
        }
        override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
            cachedInterfacesList = null
            updateDefaultInterface(network)
        }
    }

    override fun onCreate() {
        super.onCreate()
        val logFile = File(getExternalFilesDir(null) ?: filesDir, "linkpc.log")
        VpnEvents.initLogFile(logFile)
        VpnEvents.log("Service", "Служба LinkpcVpnService создана (лог: ${logFile.absolutePath})")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY

        if (action == ACTION_START) {
            // Android requirement: startForeground immediately
            ensureForegroundNotification("Подключение к шлюзу linkpc...")

            val config = intent.getStringExtra(EXTRA_CONFIG) ?: ""
            if (config.isBlank()) {
                VpnEvents.log("Service", "Ошибка: передан пустой конфиг")
                stopTunnel()
                return START_NOT_STICKY
            }

            Thread({
                startTunnel(config)
            }, "linkpc-tunnel-start").start()

        } else if (action == ACTION_STOP) {
            Thread({
                stopTunnel()
            }, "linkpc-tunnel-stop").start()
        }

        return START_NOT_STICKY
    }

    @Synchronized
    private fun startTunnel(config: String) {
        if (isRunning) {
            VpnEvents.log("Service", "Туннель уже запущен")
            return
        }

        VpnEvents.sendStatus("connecting")
        VpnEvents.log("Service", "Запуск туннеля linkpc...")

        try {
            val baseDir = filesDir
            baseDir.mkdirs()
            val workingDir = getExternalFilesDir(null) ?: filesDir
            workingDir.mkdirs()
            val tempDir = cacheDir
            tempDir.mkdirs()

            if (!isLibboxSetup) {
                try {
                    VpnEvents.log("Core", "Инициализация libbox runtime (baseDir=${baseDir.path})...")
                    Libbox.setup(SetupOptions().apply {
                        basePath = baseDir.path
                        this.workingPath = workingDir.path
                        this.tempPath = tempDir.path
                        fixAndroidStack = true
                        logMaxLines = 3000
                        debug = false
                    })
                    isLibboxSetup = true
                    VpnEvents.log("Core", "libbox runtime успешно настроен")
                } catch (e: Exception) {
                    VpnEvents.log("Core", "Предупреждение libbox.setup: ${e.message}")
                    isLibboxSetup = true
                }
            }

            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            val currentNet = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                connectivityManager?.activeNetwork
            } else null
            val initialNet = currentNet ?: findUnderlyingNetwork()
            if (initialNet != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                try {
                    setUnderlyingNetworks(arrayOf(initialNet))
                    VpnEvents.log("Network", "Установлена базовая сеть (underlying): $initialNet")
                } catch (e: Exception) {
                    VpnEvents.log("Network", "Ошибка setUnderlyingNetworks: ${e.message}")
                }
            }

            // Register network callback specifically for non-VPN internet networks on dedicated background handler thread
            try {
                val request = NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                    .build()
                val thread = android.os.HandlerThread("linkpc-net-monitor").apply { start() }
                networkHandlerThread = thread
                val handler = android.os.Handler(thread.looper)
                connectivityManager?.registerNetworkCallback(request, networkCallback, handler)
                VpnEvents.log("Network", "Запущен мониторинг физических сетей (Wi-Fi / Mobile)")
            } catch (e: Exception) {
                VpnEvents.log("Network", "Ошибка registerNetworkCallback: ${e.message}")
            }

            val server = CommandServer(this, this)
            server.start()
            commandServer = server

            VpnEvents.log("Core", "Запуск sing-box CommandServer с конфигурацией...")
            server.startOrReloadService(config, OverrideOptions())
            isRunning = true

            // Connect CommandClient to stream live sing-box logs and real traffic metrics
            val clientOptions = CommandClientOptions().apply {
                addCommand(Libbox.CommandLog)
                addCommand(Libbox.CommandStatus)
                // Go time.Duration is in nanoseconds: 1_000_000_000L = 1.0 second (not 1000L microseconds!)
                statusInterval = 1_000_000_000L
            }
            startMonitoringClient(clientOptions)

            VpnEvents.sendStatus("connected")
            updateForegroundNotification("Шлюз linkpc активен • Трафик зашифрован")
            VpnEvents.log("Service", "Туннель linkpc успешно запущен и готов к передаче данных")
        } catch (e: Throwable) {
            VpnEvents.log("Error", "Критическая ошибка запуска туннеля: ${e.message}")
            stopTunnel()
        }
    }

    private fun startMonitoringClient(options: CommandClientOptions) {
        if (!isRunning) return
        try {
            val client = CommandClient(object : CommandClientHandler {
                override fun clearLogs() {}
                override fun connected() {
                    VpnEvents.log("Client", "Подключен клиент мониторинга sing-box core")
                }
                override fun disconnected(message: String) {
                    if (!isRunning) {
                        VpnEvents.log("Client", "Клиент мониторинга штатно отключен")
                        return
                    }
                    VpnEvents.log("Client", "Отключен клиент мониторинга: $message (переподключение через 2с...)")
                    mainHandler.postDelayed({
                        if (isRunning && commandServer != null) {
                            startMonitoringClient(options)
                        }
                    }, 2000)
                }
                override fun initializeClashMode(modeList: StringIterator, currentMode: String) {}
                override fun setDefaultLogLevel(level: Int) {}
                override fun updateClashMode(newMode: String) {}
                override fun writeConnectionEvents(events: ConnectionEvents) {}
                override fun writeGroups(groups: OutboundGroupIterator) {}
                override fun writeLogs(messageList: LogIterator) {
                    while (messageList.hasNext()) {
                        val entry = messageList.next()
                        val msg = entry?.message ?: ""
                        val level = entry?.level ?: 0
                        // In libbox: 0 = trace, 1 = debug, 2 = info, 3 = warn, 4 = error, 5 = fatal, 6 = panic
                        // Filter out trace (0) and debug (1) noise unless it's a real ERROR/WARN
                        // (exclude false-positive 'NOERROR' DNS responses)
                        if (level < 2) {
                            val isRealErr = (msg.contains("ERROR[") || msg.contains("FATAL") || msg.contains("PANIC") ||
                                    (msg.contains("ERROR") && !msg.contains("NOERROR")))
                            if (!isRealErr && !msg.contains("WARN")) {
                                continue
                            }
                        }
                        if (msg.isNotBlank()) {
                            VpnEvents.log("box", msg)
                        }
                    }
                }
                override fun writeOutbounds(outbounds: OutboundGroupItemIterator) {}
                override fun writeStatus(status: StatusMessage) {
                    VpnEvents.sendTraffic(
                        status.uplink,
                        status.downlink,
                        status.uplinkTotal,
                        status.downlinkTotal
                    )
                }
            }, options)

            client.connect()
            commandClient = client
        } catch (e: Throwable) {
            VpnEvents.log("Client", "Не удалось запустить CommandClient логов: ${e.message}")
            if (isRunning) {
                mainHandler.postDelayed({
                    if (isRunning && commandServer != null) {
                        startMonitoringClient(options)
                    }
                }, 3000)
            }
        }
    }

    @Synchronized
    private fun stopTunnel() {
        isRunning = false
        VpnEvents.sendStatus("disconnecting")
        VpnEvents.log("Service", "Остановка сетевого шлюза linkpc...")

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                setUnderlyingNetworks(null)
            }
        } catch (_: Exception) {}

        try {
            commandClient?.disconnect()
        } catch (e: Exception) {
            VpnEvents.log("Client", "Ошибка отключения commandClient: ${e.message}")
        } finally {
            commandClient = null
        }

        try {
            commandServer?.closeService()
            commandServer?.close()
        } catch (e: Exception) {
            VpnEvents.log("Core", "Ошибка закрытия commandServer: ${e.message}")
        } finally {
            commandServer = null
        }

        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            VpnEvents.log("TUN", "Ошибка закрытия vpnInterface: ${e.message}")
        } finally {
            vpnInterface = null
        }

        try {
            connectivityManager?.unregisterNetworkCallback(networkCallback)
        } catch (_: Exception) {}
        try {
            networkHandlerThread?.quitSafely()
        } catch (_: Exception) {}
        networkHandlerThread = null
        lastTargetNet = null
        lastInterfaceName = null
        lastInterfaceIndex = -1

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            Log.w(TAG, "stopForeground error", e)
        }

        VpnEvents.sendStatus("disconnected")
        VpnEvents.log("Service", "Шлюз linkpc полностью остановлен")
        stopSelf()
    }

    override fun onDestroy() {
        stopTunnel()
        super.onDestroy()
    }

    override fun onRevoke() {
        VpnEvents.log("Service", "VPN разрешение отозвано системой Android")
        stopTunnel()
    }

    // --- PlatformInterface implementation ---

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        try {
            val ok = protect(fd)
            if (!ok) {
                VpnEvents.log("Socket", "Предупреждение: protect(fd=$fd) вернул false")
            }
        } catch (e: Exception) {
            VpnEvents.log("Socket", "Ошибка protect(fd=$fd): ${e.message}")
        }
    }

    override fun openTun(options: TunOptions): Int {
        if (prepare(this) != null) {
            VpnEvents.log("TUN", "Ошибка: отсутствует системное разрешение VPN")
            throw IllegalStateException("Missing VPN permission")
        }

        VpnEvents.log("TUN", "Инициализация TUN адаптера (MTU=${if (options.mtu > 0) options.mtu else 1500}, autoRoute=${options.autoRoute})...")

        val mtu = if (options.mtu in 1280..1500) options.mtu else 1400
        val builder = Builder()
            .setSession("linkpc Gateway")
            .setMtu(mtu)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        // Exclude linkpc itself to prevent routing loops
        try {
            builder.addDisallowedApplication(packageName)
            VpnEvents.log("TUN", "Исключено собственное приложение из туннеля ($packageName)")
        } catch (_: Exception) {}

        try {
            val excludeIt = options.excludePackage
            while (excludeIt != null && excludeIt.hasNext()) {
                val pkg = excludeIt.next()
                if (!pkg.isNullOrBlank() && pkg != packageName) {
                    try {
                        builder.addDisallowedApplication(pkg)
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}

        var hasInet4 = false
        try {
            val inet4 = options.inet4Address
            while (inet4 != null && inet4.hasNext()) {
                val addr = inet4.next()
                if (addr != null) {
                    val ip = addr.address()
                    val prefix = addr.prefix()
                    if (!ip.isNullOrBlank()) {
                        builder.addAddress(ip, prefix)
                        VpnEvents.log("TUN", "Назначен IPv4 адрес: $ip/$prefix")
                        hasInet4 = true
                    }
                }
            }
        } catch (e: Exception) {
            VpnEvents.log("TUN", "Ошибка настройки IPv4 TUN: ${e.message}")
        }

        if (!hasInet4) {
            try {
                builder.addAddress("172.19.0.1", 30)
                VpnEvents.log("TUN", "Назначен резервный IPv4 адрес: 172.19.0.1/30")
                hasInet4 = true
            } catch (e: Exception) {
                VpnEvents.log("TUN", "Ошибка резервного IPv4 адреса: ${e.message}")
            }
        }

        var hasInet6 = false
        try {
            val inet6 = options.inet6Address
            while (inet6 != null && inet6.hasNext()) {
                val addr = inet6.next()
                if (addr != null) {
                    val ip = addr.address()
                    val prefix = addr.prefix()
                    if (!ip.isNullOrBlank()) {
                        builder.addAddress(ip, prefix)
                        VpnEvents.log("TUN", "Назначен IPv6 адрес: $ip/$prefix")
                        hasInet6 = true
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error configuring IPv6 TUN address", e)
        }



        if (options.autoRoute) {
            try {
                val dnsIt = options.dnsServerAddress
                while (dnsIt != null && dnsIt.hasNext()) {
                    val dns = dnsIt.next()
                    if (!dns.isNullOrBlank()) {
                        builder.addDnsServer(dns)
                        VpnEvents.log("TUN", "Добавлен DNS сервер: $dns")
                    }
                }
            } catch (e: Exception) {
                VpnEvents.log("TUN", "Ошибка настройки DNS: ${e.message}")
            }

            // Always add virtual gateway DNS
            try {
                builder.addDnsServer("172.19.0.2")
            } catch (_: Exception) {}

            // Also configure well-known DNS servers (all intercepted by hijack-dns)
            try {
                builder.addDnsServer("1.1.1.1")
                builder.addDnsServer("8.8.8.8")
                builder.addDnsServer("77.88.8.8")
            } catch (_: Exception) {}

            val addedRoutes = HashSet<String>()
            var hasR4 = false
            try {
                val r4 = options.inet4RouteAddress
                while (r4 != null && r4.hasNext()) {
                    val p = r4.next()
                    if (p != null) {
                        val ip = p.address()
                        val prefix = p.prefix()
                        if (!ip.isNullOrBlank() && addedRoutes.add("$ip/$prefix")) {
                            builder.addRoute(ip, prefix)
                            VpnEvents.log("TUN", "Добавлен маршрут: $ip/$prefix")
                            hasR4 = true
                        }
                    }
                }
            } catch (e: Exception) {
                VpnEvents.log("TUN", "Ошибка настройки маршрутов: ${e.message}")
            }

            if (hasInet4 && (!hasR4 || !addedRoutes.contains("0.0.0.0/0"))) {
                try {
                    if (addedRoutes.add("0.0.0.0/0")) {
                        builder.addRoute("0.0.0.0", 0)
                        VpnEvents.log("TUN", "Добавлен дефолтный IPv4 маршрут (0.0.0.0/0)")
                    }
                } catch (e: Exception) {
                    VpnEvents.log("TUN", "Ошибка добавления маршрута 0.0.0.0/0: ${e.message}")
                }
            }

            if (hasInet6) {
                var hasR6 = false
                try {
                    val r6 = options.inet6RouteAddress
                    while (r6 != null && r6.hasNext()) {
                        val p = r6.next()
                        if (p != null) {
                            val ip = p.address()
                            val prefix = p.prefix()
                            if (!ip.isNullOrBlank()) {
                                builder.addRoute(ip, prefix)
                                VpnEvents.log("TUN", "Добавлен IPv6 маршрут: $ip/$prefix")
                                hasR6 = true
                            }
                        }
                    }
                    if (!hasR6) {
                        builder.addRoute("::", 0)
                        VpnEvents.log("TUN", "Добавлен дефолтный IPv6 маршрут (::/0)")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "IPv6 route configuration omitted", e)
                }
            }
        }

        val pfd = builder.establish() ?: throw IllegalStateException("Cannot establish VPN interface")
        vpnInterface = pfd
        VpnEvents.log("TUN", "TUN сетевой интерфейс успешно создан (fd=${pfd.fd})")
        return pfd.fd
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        defaultInterfaceListener = listener
        updateDefaultInterface()
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        defaultInterfaceListener = null
    }

    private fun findUnderlyingNetwork(): Network? {
        val cm = connectivityManager ?: (getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager) ?: return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val networks = cm.allNetworks ?: return null
            // 1. Prefer Wi-Fi or Ethernet
            for (net in networks) {
                val caps = cm.getNetworkCapabilities(net) ?: continue
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
                if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN) &&
                    caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                    if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) || caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) {
                        return net
                    }
                }
            }
            // 2. Next prefer Cellular
            for (net in networks) {
                val caps = cm.getNetworkCapabilities(net) ?: continue
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
                if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN) &&
                    caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                    if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                        return net
                    }
                }
            }
            // 3. Fallback: any network with NOT_VPN
            for (net in networks) {
                val caps = cm.getNetworkCapabilities(net) ?: continue
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
                if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)) {
                    return net
                }
            }
        }
        return null
    }

    private fun updateDefaultInterface(specifiedNetwork: Network? = null) {
        try {
            val cm = connectivityManager ?: (getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager) ?: return

            fun isValidPhysical(net: Network?): Boolean {
                if (net == null) return false
                val c = cm.getNetworkCapabilities(net) ?: return false
                return !c.hasTransport(NetworkCapabilities.TRANSPORT_VPN) &&
                       c.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN) &&
                       c.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            }

            val targetNet = when {
                isValidPhysical(specifiedNetwork) -> specifiedNetwork
                isValidPhysical(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) cm.activeNetwork else null) ->
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) cm.activeNetwork else null
                else -> findUnderlyingNetwork()
            }

            if (targetNet == null) {
                VpnEvents.log("Network", "Физическая сеть не обнаружена")
                defaultInterfaceListener?.updateDefaultInterface("", -1, false, false)
                return
            }

            // Only update underlying network on VpnService if target physical network actually changed
            val targetNetChanged = (targetNet != lastTargetNet)
            if (targetNetChanged) {
                lastTargetNet = targetNet
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                    try {
                        setUnderlyingNetworks(arrayOf(targetNet))
                    } catch (e: Exception) {
                        VpnEvents.log("Network", "Ошибка setUnderlyingNetworks: ${e.message}")
                    }
                }
            }

            val listener = defaultInterfaceListener ?: return

            val lp = cm.getLinkProperties(targetNet)
            val ifName = lp?.interfaceName ?: ""
            if (ifName.isBlank() || ifName.startsWith("tun") || ifName.startsWith("ppp")) {
                return
            }

            val caps = cm.getNetworkCapabilities(targetNet)
            val isExpensive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && caps != null) {
                !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            } else false

            val isConstrained = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && caps != null) {
                !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_CONGESTED)
            } else false

            val ifIdx = try {
                val idx = NetworkInterface.getByName(ifName)?.index ?: 0
                if (idx > 0) idx else (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) (targetNet.networkHandle.toInt() and 0x7FFFFFFF) else 0)
            } catch (_: Exception) {
                0
            }

            // Deduplicate: do NOT reset sing-box routing table if physical interface has not changed
            if (!targetNetChanged && lastInterfaceName == ifName && lastInterfaceIndex == ifIdx) {
                return
            }
            lastInterfaceName = ifName
            lastInterfaceIndex = ifIdx
            lastIsExpensive = isExpensive
            lastIsConstrained = isConstrained

            VpnEvents.log("Network", "Основной физический интерфейс: $ifName (индекс=$ifIdx, лимитный=$isExpensive)")
            listener.updateDefaultInterface(ifName, ifIdx, isExpensive, isConstrained)
        } catch (e: Exception) {
            VpnEvents.log("Network", "Ошибка updateDefaultInterface: ${e.message}")
        }
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val now = android.os.SystemClock.elapsedRealtime()
        val cached = cachedInterfacesList
        if (cached != null && (now - lastInterfacesTime < 5000L)) {
            return InterfaceArray(cached)
        }

        val list = mutableListOf<io.nekohasekai.libbox.NetworkInterface>()
        try {
            val cm = connectivityManager ?: (getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager)
            val networks = cm?.allNetworks
            val javaInterfaces = try {
                val nifs = NetworkInterface.getNetworkInterfaces()
                val res = mutableListOf<NetworkInterface>()
                while (nifs != null && nifs.hasMoreElements()) {
                    val n = nifs.nextElement()
                    if (n != null) res.add(n)
                }
                res
            } catch (_: Exception) {
                emptyList<NetworkInterface>()
            }

            if (cm != null && networks != null && networks.isNotEmpty()) {
                for (network in networks) {
                    val caps = cm.getNetworkCapabilities(network) ?: continue
                    if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
                    if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)) continue

                    val lp = cm.getLinkProperties(network) ?: continue
                    val ifName = lp.interfaceName ?: continue
                    if (ifName.isBlank() || ifName.startsWith("tun") || ifName.startsWith("ppp")) continue

                    val nif = javaInterfaces.find { it.name == ifName }

                    val boxIf = io.nekohasekai.libbox.NetworkInterface()
                    boxIf.name = ifName
                    boxIf.index = nif?.index ?: (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) (network.networkHandle.toInt() and 0x7FFFFFFF) else 1)
                    boxIf.mtu = try { if ((nif?.mtu ?: 0) > 0) nif!!.mtu else 1500 } catch (_: Exception) { 1500 }

                    val addrs = mutableListOf<String>()
                    val interfaceAddresses = try { nif?.interfaceAddresses } catch (_: Exception) { null }
                    if (interfaceAddresses != null) {
                        for (ia in interfaceAddresses) {
                            try {
                                val addr = ia?.address ?: continue
                                val host = (addr.hostAddress ?: continue).substringBefore('%')
                                val prefix = ia.networkPrefixLength.toInt()
                                val validPrefix = if (prefix > 0) prefix else (if (addr is java.net.Inet6Address) 128 else 32)
                                addrs.add("$host/$validPrefix")
                            } catch (_: Exception) {}
                        }
                    }
                    if (addrs.isEmpty()) {
                        for (la in lp.linkAddresses) {
                            try {
                                val host = la.address.hostAddress?.substringBefore('%') ?: continue
                                addrs.add("$host/${la.prefixLength}")
                            } catch (_: Exception) {}
                        }
                    }
                    boxIf.addresses = StringArray(addrs)

                    // DNS servers
                    val dnsList = lp.dnsServers.mapNotNull { it.hostAddress?.substringBefore('%') }
                    boxIf.dnsServer = StringArray(dnsList)

                    // Gateways
                    val gateways = lp.routes
                        .filter { it.destination?.prefixLength == 0 }
                        .mapNotNull { it.gateway?.hostAddress?.substringBefore('%') }
                        .filterNot { it.startsWith("0.0.0.0") || it == "::" }
                    boxIf.gateway = StringArray(gateways)

                    // Type
                    boxIf.type = when {
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Libbox.InterfaceTypeCellular
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Libbox.InterfaceTypeEthernet
                        else -> Libbox.InterfaceTypeOther
                    }

                    // Flags - MUST HAVE IFF_UP and IFF_RUNNING so sing-box marks it active!
                    var flags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
                    if (nif != null) {
                        if (try { nif.isLoopback } catch (_: Exception) { false }) flags = flags or OsConstants.IFF_LOOPBACK
                        if (try { nif.isPointToPoint } catch (_: Exception) { false }) flags = flags or OsConstants.IFF_POINTOPOINT
                        if (try { nif.supportsMulticast() } catch (_: Exception) { false }) flags = flags or OsConstants.IFF_MULTICAST
                    }
                    boxIf.flags = flags

                    // Metered
                    boxIf.metered = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
                    } else false

                    list.add(boxIf)
                }
            }

            // Fallback: if no interfaces found from ConnectivityManager, populate from NetworkInterface
            if (list.isEmpty()) {
                for (nif in javaInterfaces) {
                    val name = nif.name ?: continue
                    if (name == "lo" || name.startsWith("tun") || name.startsWith("dummy") || name.startsWith("p2p")) continue
                    val isUp = try { nif.isUp } catch (_: Exception) { true }
                    if (!isUp) continue

                    val boxIf = io.nekohasekai.libbox.NetworkInterface()
                    boxIf.name = name
                    boxIf.index = nif.index
                    boxIf.mtu = try { if (nif.mtu > 0) nif.mtu else 1500 } catch (_: Exception) { 1500 }

                    val addrs = mutableListOf<String>()
                    val interfaceAddresses = try { nif.interfaceAddresses } catch (_: Exception) { null }
                    if (interfaceAddresses != null) {
                        for (ia in interfaceAddresses) {
                            try {
                                val addr = ia?.address ?: continue
                                val host = (addr.hostAddress ?: continue).substringBefore('%')
                                val prefix = ia.networkPrefixLength.toInt()
                                val validPrefix = if (prefix > 0) prefix else (if (addr is java.net.Inet6Address) 128 else 32)
                                addrs.add("$host/$validPrefix")
                            } catch (_: Exception) {}
                        }
                    }
                    boxIf.addresses = StringArray(addrs)
                    boxIf.flags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
                    boxIf.type = when {
                        name.contains("wlan") -> Libbox.InterfaceTypeWIFI
                        name.contains("rmnet") || name.contains("lte") || name.contains("seth") || name.contains("ccmni") -> Libbox.InterfaceTypeCellular
                        name.contains("eth") -> Libbox.InterfaceTypeEthernet
                        else -> Libbox.InterfaceTypeOther
                    }
                    list.add(boxIf)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "getInterfaces error", e)
        }
        cachedInterfacesList = list
        lastInterfacesTime = android.os.SystemClock.elapsedRealtime()
        return InterfaceArray(list)
    }

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int
    ): ConnectionOwner {
        val owner = ConnectionOwner()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val cm = connectivityManager ?: (getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager)
                val uid = cm?.getConnectionOwnerUid(
                    ipProtocol,
                    InetSocketAddress(sourceAddress, sourcePort),
                    InetSocketAddress(destinationAddress, destinationPort)
                ) ?: Process.INVALID_UID
                owner.userId = uid
                if (uid > 0 && uid != Process.INVALID_UID) {
                    val cached = uidPackageCache[uid]
                    if (cached != null) {
                        owner.userName = cached.first
                        owner.setAndroidPackageNames(StringArray(cached.second))
                    } else {
                        val pkgs = packageManager.getPackagesForUid(uid)
                        val pkgList = pkgs?.toList() ?: emptyList()
                        val firstName = pkgs?.firstOrNull() ?: ""
                        uidPackageCache[uid] = Pair(firstName, pkgList)
                        owner.userName = firstName
                        owner.setAndroidPackageNames(StringArray(pkgList))
                    }
                }
            }
        } catch (_: Exception) {}
        return owner
    }

    override fun underNetworkExtension(): Boolean = false
    override fun includeAllNetworks(): Boolean = false
    override fun clearDNSCache() {}
    override fun readWIFIState(): WIFIState? = null
    override fun localDNSTransport(): LocalDNSTransport? = null
    override fun startNeighborMonitor(listener: NeighborUpdateListener?) {}
    override fun closeNeighborMonitor(listener: NeighborUpdateListener?) {}
    override fun usePlatformShell(): Boolean = false
    override fun checkPlatformShell() {}
    override fun openShellSession(
        user: PlatformUser?, command: String?, environ: StringIterator?,
        term: String?, rows: Int, cols: Int
    ): ShellSession = throw UnsupportedOperationException()
    override fun readSystemSSHHostKey(): String = throw UnsupportedOperationException()
    override fun lookupSFTPServer(): String = throw UnsupportedOperationException()
    override fun tailscaleHostname(): String = "${Build.MANUFACTURER} ${Build.MODEL}"
    override fun usePlatformBridge(): Boolean = false
    override fun createBridge(options: BridgeOptions?): BridgeSession = throw UnsupportedOperationException()
    override fun lookupUser(username: String?): PlatformUser = throw UnsupportedOperationException()
    override fun registerMyInterface(name: String?) {}
    override fun sendNotification(notification: io.nekohasekai.libbox.Notification) {}
    override fun cancelNotification(identifier: String?, typeID: Int) {}

    // --- CommandServerHandler implementation ---

    override fun connectSSHAgent(): Int = -1
    override fun getSystemProxyStatus(): SystemProxyStatus = SystemProxyStatus().apply {
        available = false
        enabled = false
    }
    override fun serviceReload() {}
    override fun serviceStop() {
        stopTunnel()
    }
    override fun setSystemProxyEnabled(enabled: Boolean) {}
    override fun triggerNativeCrash() {}
    override fun writeDebugMessage(message: String) {
        Log.d(TAG, message)
        VpnEvents.log("libbox", message)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Состояние шлюза linkpc"
            val descriptionText = "Уведомления о работе защищенного сетевого туннеля"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun getAppIcon(): Int {
        val icon = applicationInfo.icon
        return if (icon != 0) icon else android.R.drawable.sym_def_app_icon
    }

    private fun buildForegroundNotification(contentText: String): Notification {
        createNotificationChannel()

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent().setClassName(packageName, "net.linkpc.client.MainActivity").apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("linkpc — Защищенное соединение")
            .setContentText(contentText)
            .setSmallIcon(getAppIcon())
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun ensureForegroundNotification(contentText: String) {
        val notification = buildForegroundNotification(contentText)
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Throwable) {
            Log.w(TAG, "startForeground with SPECIAL_USE failed, falling back to standard startForeground", e)
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (e2: Throwable) {
                Log.e(TAG, "Fallback startForeground also failed", e2)
            }
        }
    }

    private fun updateForegroundNotification(contentText: String) {
        try {
            val notification = buildForegroundNotification(contentText)
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.notify(NOTIFICATION_ID, notification)
        } catch (e: Throwable) {
            Log.w(TAG, "Failed to update notification", e)
        }
    }
}
