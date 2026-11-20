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
import android.os.ParcelFileDescriptor
import android.os.Process
import android.util.Log
import io.nekohasekai.libbox.*
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

    private var vpnInterface: ParcelFileDescriptor? = null
    private var commandServer: CommandServer? = null
    private var defaultInterfaceListener: InterfaceUpdateListener? = null
    private var connectivityManager: ConnectivityManager? = null

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            Log.i(TAG, "Physical network available: $network")
            updateDefaultInterface(network)
        }
        override fun onLost(network: Network) {
            Log.i(TAG, "Physical network lost: $network")
            updateDefaultInterface()
        }
        override fun onLinkPropertiesChanged(network: Network, linkProperties: android.net.LinkProperties) {
            updateDefaultInterface(network)
        }
        override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
            updateDefaultInterface(network)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY

        if (action == ACTION_START) {
            // Android 8-14 requirement: call startForeground IMMEDIATELY to prevent ForegroundServiceDidNotStartInTimeException
            ensureForegroundNotification("Подключение к шлюзу linkpc...")

            val config = intent.getStringExtra(EXTRA_CONFIG) ?: ""
            if (config.isBlank()) {
                Log.e(TAG, "Empty config provided to onStartCommand, stopping")
                stopTunnel()
                return START_NOT_STICKY
            }

            // Start sing-box core on a worker thread to avoid blocking Android main UI thread
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
            Log.i(TAG, "Tunnel already active")
            return
        }

        try {
            val baseDir = filesDir
            baseDir.mkdirs()
            val workingDir = getExternalFilesDir(null) ?: filesDir
            workingDir.mkdirs()
            val tempDir = cacheDir
            tempDir.mkdirs()

            if (!isLibboxSetup) {
                try {
                    Libbox.setup(SetupOptions().apply {
                        basePath = baseDir.path
                        this.workingPath = workingDir.path
                        this.tempPath = tempDir.path
                        fixAndroidStack = true
                        logMaxLines = 3000
                        debug = false
                    })
                    isLibboxSetup = true
                } catch (e: Exception) {
                    Log.w(TAG, "Libbox.setup error (may be already initialized)", e)
                    isLibboxSetup = true
                }
            }

            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    // Only listen to physical networks that have Internet and are NOT a VPN
                    val request = NetworkRequest.Builder()
                        .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                        .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                        .build()
                    connectivityManager?.registerNetworkCallback(request, networkCallback)
                }
            } catch (e: Exception) {
                Log.w(TAG, "registerNetworkCallback failed", e)
            }

            val server = CommandServer(this, this)
            server.start()
            commandServer = server

            Log.i(TAG, "Starting sing-box commandServer with config...")
            server.startOrReloadService(config, OverrideOptions())
            isRunning = true

            updateForegroundNotification("Шлюз linkpc активен • Трафик зашифрован")
            Log.i(TAG, "linkpc tunnel successfully started")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to start tunnel", e)
            stopTunnel()
        }
    }

    @Synchronized
    private fun stopTunnel() {
        isRunning = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                setUnderlyingNetworks(null)
            }
        } catch (_: Exception) {}

        try {
            commandServer?.closeService()
            commandServer?.close()
        } catch (e: Exception) {
            Log.e(TAG, "close commandServer error", e)
        } finally {
            commandServer = null
        }

        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "close vpnInterface error", e)
        } finally {
            vpnInterface = null
        }

        try {
            connectivityManager?.unregisterNetworkCallback(networkCallback)
        } catch (_: Exception) {}

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            Log.w(TAG, "stopForeground error", e)
        }
        stopSelf()
    }

    override fun onDestroy() {
        stopTunnel()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopTunnel()
    }

    // --- PlatformInterface implementation ---

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        try {
            val ok = protect(fd)
            if (!ok) {
                Log.w(TAG, "protect(fd=$fd) returned false")
            }
        } catch (e: Exception) {
            Log.w(TAG, "protect(fd) failed", e)
        }
    }

    override fun openTun(options: TunOptions): Int {
        if (prepare(this) != null) {
            throw IllegalStateException("Missing VPN permission")
        }

        val builder = Builder()
            .setSession("linkpc Gateway")
            .setMtu(if (options.mtu > 0) options.mtu else 1500)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        // Exclude linkpc itself to prevent routing loops
        try {
            builder.addDisallowedApplication(packageName)
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
                        hasInet4 = true
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error configuring IPv4 TUN address", e)
        }

        if (!hasInet4) {
            try {
                builder.addAddress("172.19.0.1", 30)
                hasInet4 = true
            } catch (e: Exception) {
                Log.w(TAG, "Fallback IPv4 address failed", e)
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
                        hasInet6 = true
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error configuring IPv6 TUN address", e)
        }

        if (options.autoRoute) {
            var dnsAdded = false
            try {
                val dnsIt = options.dnsServerAddress
                while (dnsIt != null && dnsIt.hasNext()) {
                    val dns = dnsIt.next()
                    if (!dns.isNullOrBlank()) {
                        builder.addDnsServer(dns)
                        dnsAdded = true
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error configuring DNS server", e)
            }

            if (!dnsAdded) {
                try {
                    builder.addDnsServer("1.1.1.1")
                    builder.addDnsServer("8.8.8.8")
                    builder.addDnsServer("77.88.8.8")
                } catch (e: Exception) {
                    Log.w(TAG, "Fallback DNS configuration failed", e)
                }
            }

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
                            hasR4 = true
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error configuring IPv4 routes", e)
            }

            if (hasInet4 && (!hasR4 || !addedRoutes.contains("0.0.0.0/0"))) {
                try {
                    if (addedRoutes.add("0.0.0.0/0")) {
                        builder.addRoute("0.0.0.0", 0)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Default IPv4 route failed", e)
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
                                hasR6 = true
                            }
                        }
                    }
                    if (!hasR6) {
                        builder.addRoute("::", 0)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "IPv6 route configuration omitted", e)
                }
            }
        }

        val pfd = builder.establish() ?: throw IllegalStateException("Cannot establish VPN interface")
        vpnInterface = pfd
        Log.i(TAG, "VPN interface established with fd=${pfd.fd}")
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
        val listener = defaultInterfaceListener ?: return
        try {
            val cm = connectivityManager ?: (getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager) ?: return
            val targetNet = specifiedNetwork ?: findUnderlyingNetwork()

            if (targetNet == null) {
                Log.w(TAG, "No underlying physical network found")
                return
            }

            val caps = cm.getNetworkCapabilities(targetNet)
            if (caps == null || caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) || !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)) {
                Log.w(TAG, "Rejecting network $targetNet: is VPN or lacks NOT_VPN")
                return
            }

            val lp = cm.getLinkProperties(targetNet)
            val ifName = lp?.interfaceName ?: ""
            if (ifName.isBlank() || ifName.startsWith("tun") || ifName.startsWith("ppp")) {
                Log.w(TAG, "Rejecting virtual interface $ifName")
                return
            }

            val ifIdx = try {
                NetworkInterface.getByName(ifName)?.index ?: -1
            } catch (_: Exception) {
                -1
            }

            val isExpensive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false
            } else false

            val isConstrained = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_CONGESTED) == false
            } else false

            Log.i(TAG, "Setting underlying default interface: $ifName (index=$ifIdx, expensive=$isExpensive)")
            listener.updateDefaultInterface(ifName, ifIdx, isExpensive, isConstrained)

            // Inform Android VpnService of the underlying physical network to prevent routing loops
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                setUnderlyingNetworks(arrayOf(targetNet))
            }
        } catch (e: Exception) {
            Log.w(TAG, "updateDefaultInterface error", e)
        }
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val list = mutableListOf<io.nekohasekai.libbox.NetworkInterface>()
        try {
            val nifs = NetworkInterface.getNetworkInterfaces()
            while (nifs != null && nifs.hasMoreElements()) {
                val nif = nifs.nextElement()
                if (nif == null || !nif.isUp) continue
                val name = nif.name ?: ""
                // Exclude loopback and virtual VPN tun interfaces from interface list
                if (name == "lo" || name.startsWith("tun") || name.startsWith("dummy") || name.startsWith("p2p")) continue

                val boxIf = io.nekohasekai.libbox.NetworkInterface()
                boxIf.index = nif.index
                boxIf.name = name
                try { boxIf.mtu = if (nif.mtu > 0) nif.mtu else 1500 } catch (_: Exception) {}
                val addrs = mutableListOf<String>()
                val interfaceAddresses = try { nif.interfaceAddresses } catch (_: Exception) { null }
                if (interfaceAddresses != null) {
                    for (ia in interfaceAddresses) {
                        try {
                            val addr = ia?.address ?: continue
                            val rawHost = addr.hostAddress ?: continue
                            // Strip IPv6 scope ID (e.g. fe80::1%wlan0 -> fe80::1) so Go netip.ParsePrefix succeeds
                            val host = rawHost.substringBefore('%')
                            val prefix = ia.networkPrefixLength.toInt()
                            val validPrefix = if (prefix > 0) prefix else (if (addr is java.net.Inet6Address) 128 else 32)
                            addrs.add("$host/$validPrefix")
                        } catch (_: Exception) {}
                    }
                }
                boxIf.addresses = StringArray(addrs)
                list.add(boxIf)
            }
        } catch (e: Exception) {
            Log.w(TAG, "getInterfaces error", e)
        }
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
                if (uid != Process.INVALID_UID) {
                    val pkgs = packageManager.getPackagesForUid(uid)
                    owner.userName = pkgs?.firstOrNull() ?: ""
                    owner.setAndroidPackageNames(StringArray(pkgs?.toList() ?: emptyList()))
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
