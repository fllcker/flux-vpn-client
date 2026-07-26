package rip.freeinternet.flux

/**
 * Routing everything (0.0.0.0/0) through the TUN would also catch xray-core's
 * own outbound connection to the VLESS/Hysteria2 server, deadlocking the
 * tunnel (same problem the Windows TunBridgeEngine works around by excluding
 * the resolved server IP from sing-box's routes — see
 * lib/engines/singbox/tun_bridge_engine.dart). VpnService.Builder has no
 * "exclude" primitive below API 33 (Builder.excludeRoute), so instead we
 * cover 0.0.0.0/0 minus the server's /32 with explicit CIDR blocks.
 */
object RouteExclusion {
    /** Splits 0.0.0.0/0 into up to 32 CIDR blocks that together cover every
     * address except [excludeIp]. */
    fun ipv4RoutesExcluding(excludeIp: String): List<Pair<String, Int>> {
        val target = ipToLong(excludeIp)
        val routes = mutableListOf<Pair<String, Int>>()
        var base = 0L
        var prefix = 0
        while (prefix < 32) {
            val blockSize = 1L shl (32 - prefix)
            val lowerBase = base
            val upperBase = base + blockSize / 2
            if (target < upperBase) {
                routes.add(Pair(longToIp(upperBase), prefix + 1))
                base = lowerBase
            } else {
                routes.add(Pair(longToIp(lowerBase), prefix + 1))
                base = upperBase
            }
            prefix += 1
        }
        return routes
    }

    private fun ipToLong(ip: String): Long {
        val parts = ip.split(".").map { it.toLong() }
        require(parts.size == 4) { "Not an IPv4 address: $ip" }
        return (parts[0] shl 24) or (parts[1] shl 16) or (parts[2] shl 8) or parts[3]
    }

    private fun longToIp(v: Long): String {
        return "${(v shr 24) and 0xFF}.${(v shr 16) and 0xFF}.${(v shr 8) and 0xFF}.${v and 0xFF}"
    }
}
