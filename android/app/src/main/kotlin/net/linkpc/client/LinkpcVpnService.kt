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

        var isRunning = false
            private set
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var commandServer: CommandServer? = null
    private var defaultInterfaceListener: InterfaceUpdateListener? = null
    private var connectivityManager: ConnectivityManager? = null

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            updateDefaultInterface()
        }
        override fun onLost(network: Network) {
            updateDefaultInterface()
        }
        override fun onLinkPropertiesChanged(network: Network, linkProperties: android.net.LinkProperties) {
            updateDefaultInterface()
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY

        if (action == ACTION_START) {
            val config = intent.getStringExtra(EXTRA_CONFIG) ?: ""
            startTunnel(config)
        } else if (action == ACTION_STOP) {
            stopTunnel()
        }

        return START_NOT_STICKY
    }

    private fun startTunnel(config: String) {
        if (isRunning) return

        try {
            val baseDir = filesDir
            baseDir.mkdirs()
            val workingDir = getExternalFilesDir(null) ?: filesDir
            workingDir.mkdirs()
            val tempDir = cacheDir
            tempDir.mkdirs()

            Libbox.setup(SetupOptions().apply {
                basePath = baseDir.path
                this.workingPath = workingDir.path
                this.tempPath = tempDir.path
                fixAndroidStack = true
                logMaxLines = 3000
                debug = false
            })

            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    connectivityManager?.registerDefaultNetworkCallback(networkCallback)
                }
            } catch (e: Exception) {
                Log.w(TAG, "registerDefaultNetworkCallback failed", e)
            }

            val server = CommandServer(this, this)
            server.start()
            commandServer = server

            Log.i(TAG, "Starting sing-box commandServer with config...")
            server.startOrReloadService(config, OverrideOptions())
            isRunning = true

            val notification = buildForegroundNotification("Шлюз linkpc активен • Трафик зашифрован")
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start tunnel", e)
            stopTunnel()
        }
    }

    private fun stopTunnel() {
        isRunning = false
        try {
            commandServer?.closeService()
            commandServer?.close()
            commandServer = null
        } catch (e: Exception) {
            Log.e(TAG, "close commandServer error", e)
        }
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Exception) {
            Log.e(TAG, "close vpnInterface error", e)
        }
        try {
            connectivityManager?.unregisterNetworkCallback(networkCallback)
        } catch (_: Exception) {}

        stopForeground(STOP_FOREGROUND_REMOVE)
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
        protect(fd)
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

        // Exclude the linkpc client itself from the VPN tunnel to prevent routing loops
        try {
            builder.addDisallowedApplication(packageName)
        } catch (_: Exception) {}

        try {
            val excludeIt = options.excludePackage
            while (excludeIt != null && excludeIt.hasNext()) {
                val pkg = excludeIt.next()
                if (pkg.isNotBlank() && pkg != packageName) {
                    builder.addDisallowedApplication(pkg)
                }
            }
        } catch (_: Exception) {}

        var hasInet4 = false
        val inet4 = options.inet4Address
        while (inet4.hasNext()) {
            hasInet4 = true
            val addr = inet4.next()
            builder.addAddress(addr.address(), addr.prefix())
        }

        var hasInet6 = false
        val inet6 = options.inet6Address
        while (inet6.hasNext()) {
            hasInet6 = true
            val addr = inet6.next()
            builder.addAddress(addr.address(), addr.prefix())
        }

        if (options.autoRoute) {
            var dnsAdded = false
            try {
                val dnsMode = options.dnsMode?.value
                if (dnsMode != Libbox.DNSModeDisabled) {
                    val dnsIt = options.dnsServerAddress
                    while (dnsIt != null && dnsIt.hasNext()) {
                        val dns = dnsIt.next()
                        if (dns.isNotBlank()) {
                            builder.addDnsServer(dns)
                            dnsAdded = true
                        }
                    }
                }
            } catch (_: Exception) {}

            if (!dnsAdded) {
                // If core did not supply explicit tunnel DNS, ensure Android VPN resolver is configured
                try {
                    builder.addDnsServer("1.1.1.1")
                    builder.addDnsServer("8.8.8.8")
                } catch (_: Exception) {}
            }

            val r4 = options.inet4RouteAddress
            var hasR4 = false
            while (r4.hasNext()) {
                hasR4 = true
                val p = r4.next()
                builder.addRoute(p.address(), p.prefix())
            }
            if (!hasR4 && hasInet4) {
                builder.addRoute("0.0.0.0", 0)
            }

            val r6 = options.inet6RouteAddress
            var hasR6 = false
            while (r6.hasNext()) {
                hasR6 = true
                val p = r6.next()
                builder.addRoute(p.address(), p.prefix())
            }
            if (!hasR6 && hasInet6) {
                builder.addRoute("::", 0)
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

    private fun updateDefaultInterface() {
        val listener = defaultInterfaceListener ?: return
        try {
            val cm = connectivityManager ?: (getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager)
            val activeNet = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) cm?.activeNetwork else null
            val lp = activeNet?.let { cm?.getLinkProperties(it) }
            val ifName = lp?.interfaceName ?: ""
            val ifIdx = try { NetworkInterface.getByName(ifName)?.index ?: -1 } catch (_: Exception) { -1 }
            listener.updateDefaultInterface(ifName, ifIdx, false, false)
        } catch (_: Exception) {}
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val list = mutableListOf<io.nekohasekai.libbox.NetworkInterface>()
        try {
            val nifs = NetworkInterface.getNetworkInterfaces()
            while (nifs != null && nifs.hasMoreElements()) {
                val nif = nifs.nextElement()
                val boxIf = io.nekohasekai.libbox.NetworkInterface()
                boxIf.index = nif.index
                boxIf.name = nif.name
                try { boxIf.mtu = nif.mtu } catch (_: Exception) {}
                val addrs = mutableListOf<String>()
                for (ia in nif.interfaceAddresses) {
                    addrs.add("${ia.address.hostAddress}/${ia.networkPrefixLength}")
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
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(contentText: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
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
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
