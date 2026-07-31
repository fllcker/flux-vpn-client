import Libbox
import NetworkExtension
import os.log

/// Реализация `LibboxPlatformInterface` — колбэки, которыми libbox (Go)
/// просит хост (нас) сделать то, что зашито в самой ОС и недоступно из Go:
/// поднять TUN, узнать список интерфейсов, состояние Wi-Fi и т.п. Единственный
/// метод, который нам реально критичен для базового TUN-режима — [openTun];
/// остальные застаблены по минимуму (Windows/macOS-стопгэп тоже не делал
/// per-process роутинг и т.п., см. комментарии в singbox_config_mapper.dart
/// про то же самое решение).
///
/// Сигнатуры методов ниже реально скомпилированы (`xcodebuild` с
/// `CODE_SIGNING_ALLOWED=NO` — линковка и сборка `.systemextension` проходят
/// чисто, см. ROADMAP.md) против `Libbox.xcframework`, собранного
/// `scripts/build_libbox_macos.sh`. НЕ проверено — сама подпись/активация
/// System Extension (нужен платный Developer-аккаунт) и поведение в
/// рантайме (реальный вызов openTun и т.п.) — это First-run-проверка у
/// друга. Протоколы называются с суффиксом `Protocol`
/// (`LibboxPlatformInterfaceProtocol`, не `LibboxPlatformInterface` —
/// последнее уже занято Go-backed классом-обёрткой), некоторые методы
/// переименованы относительно `Libbox.objc.h` (`autoDetectControl` вместо
/// `autoDetectInterfaceControl` и т.п.) — тоже по факту компиляции, а не по
/// заголовку.
final class FluxPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol {
  private weak var provider: NEPacketTunnelProvider?

  init(provider: NEPacketTunnelProvider) {
    self.provider = provider
  }

  /// Единственный по-настоящему важный метод: libbox зовёт его из
  /// tun-инбаунда с уже готовыми адресами/маршрутами/DNS (то, что раньше
  /// sing-box настраивал сам через `auto_route` поверх голого `utun`, см.
  /// `singbox_config_mapper.dart`) — здесь это транслируется в
  /// `NEPacketTunnelNetworkSettings`, и именно поэтому наш TUN теперь не
  /// конфликтует по приоритету с другими системными VPN (см. инцидент с
  /// v2RayTun, ROADMAP.md) — `setTunnelNetworkSettings` регистрирует маршруты
  /// через тот же официальный механизм, что и они.
  func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
    guard let options, let provider else {
      throw FluxTunnelError.missingConfig
    }

    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

    let ipv4 = NEIPv4Settings(
      addresses: FluxRouteHelpers.addresses(from: options.getInet4Address()),
      subnetMasks: FluxRouteHelpers.masks(from: options.getInet4Address())
    )
    if options.getAutoRoute() {
      ipv4.includedRoutes = [NEIPv4Route.default()]
    } else {
      ipv4.includedRoutes = FluxRouteHelpers.routes(from: options.getInet4RouteAddress())
        + FluxRouteHelpers.routes(from: options.getInet4RouteRange())
    }
    ipv4.excludedRoutes = FluxRouteHelpers.routes(from: options.getInet4RouteExcludeAddress())
    settings.ipv4Settings = ipv4

    if let inet6 = options.getInet6Address(), FluxRouteHelpers.hasAny(inet6) {
      let ipv6 = NEIPv6Settings(
        addresses: FluxRouteHelpers.addresses(from: options.getInet6Address()),
        networkPrefixLengths: FluxRouteHelpers.prefixLengths(from: options.getInet6Address())
      )
      if options.getAutoRoute() {
        ipv6.includedRoutes = [NEIPv6Route.default()]
      } else {
        ipv6.includedRoutes = FluxRouteHelpers.ipv6Routes(from: options.getInet6RouteAddress())
          + FluxRouteHelpers.ipv6Routes(from: options.getInet6RouteRange())
      }
      ipv6.excludedRoutes = FluxRouteHelpers.ipv6Routes(from: options.getInet6RouteExcludeAddress())
      settings.ipv6Settings = ipv6
    }

    if let dnsBox = try? options.getDNSServerAddress(), !dnsBox.value.isEmpty {
      settings.dnsSettings = NEDNSSettings(servers: [dnsBox.value])
      // Пустой matchDomains — все DNS-запросы, а не только под конкретный
      // домен, тот же смысл, что у `hijack-dns`-правила в
      // singbox_config_mapper.dart для Windows/старого macOS-стопгэпа.
      settings.dnsSettings?.matchDomains = [""]
    }

    settings.mtu = NSNumber(value: options.getMTU())

    let semaphore = DispatchSemaphore(value: 0)
    var settingsError: Error?
    provider.setTunnelNetworkSettings(settings) { error in
      settingsError = error
      semaphore.signal()
    }
    // setTunnelNetworkSettings асинхронный, а openTun (вызывается из Go)
    // должен вернуть готовый fd синхронно — ждём результата так же, как
    // ждали бы ответа на нативный системный вызов.
    semaphore.wait()
    if let settingsError {
      throw settingsError
    }

    // `packetFlow` не даёт публичного API на сырой fd — тот же приём,
    // которым пользуются другие NEPacketTunnelProvider-based клиенты
    // (WireGuardKit и т.п.): значение лежит в приватном свойстве
    // `socket.fileDescriptor` самого packetFlow, доступном через KVC.
    guard
      let fd = (provider.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32),
      fd >= 0
    else {
      throw FluxTunnelError.noTunnelFileDescriptor
    }
    ret0_?.pointee = fd
  }

  // autoDetectInterfaceControl/sendNotification/usePlatformAutoDetectInterfaceControl
  // переименованы в самом протоколе (Xcode: "has been renamed to ...") —
  // имена ниже уже исправлены по реальной ошибке компилятора.
  func autoDetectControl(_ fd: Int32) throws {}

  func clearDNSCache() {}

  func closeDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {}

  // Методы ниже возвращают nullable-объект и одновременно throws — Swift
  // requires non-optional return type в этом случае ("throws" сам выражает
  // отсутствие результата, `nil` при throws запрещён компилятором). Раз
  // застаблено — throw вместо return nil.
  func findConnectionOwner(
    _ ipProtocol: Int32,
    sourceAddress: String?,
    sourcePort: Int32,
    destinationAddress: String?,
    destinationPort: Int32
  ) throws -> LibboxConnectionOwner {
    // Тот же осознанный отказ от per-process поиска владельца соединения,
    // что уже описан в singbox_config_mapper.dart (Windows) — платить
    // перечислением таблицы соединений на каждый коннект ради страховки,
    // уже дважды покрытой route_exclude_address/ip_cidr-правилами, не имеет
    // смысла.
    throw FluxTunnelError.notImplemented
  }

  func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
    throw FluxTunnelError.notImplemented
  }

  func includeAllNetworks() -> Bool { false }

  func localDNSTransport() -> LibboxLocalDNSTransportProtocol? { nil }

  func readWIFIState() -> LibboxWIFIState? { nil }

  func send(_ notification: LibboxNotification?) throws {}

  func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {}

  func systemCertificates() -> LibboxStringIteratorProtocol? { nil }

  func underNetworkExtension() -> Bool { true }

  func usePlatformAutoDetectControl() -> Bool { false }

  func useProcFS() -> Bool { false }
}

/// Минимальный `LibboxCommandServerHandler` — нам не нужны Clash API/группы
/// выбора аутбаунда, только базовый lifecycle (см. `PacketTunnelProvider`).
final class FluxCommandServerHandler: NSObject, LibboxCommandServerHandlerProtocol {
  func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
    throw FluxTunnelError.notImplemented
  }

  func serviceReload() throws {}

  func serviceStop() throws {}

  func setSystemProxyEnabled(_ enabled: Bool) throws {
    // Системный прокси — забота Proxy-режима (`XrayEngineMacOS` +
    // `networksetup`, см. macos_system_proxy.dart), TUN его не трогает.
  }

  func writeDebugMessage(_ message: String?) {
    if let message {
      os_log("%{public}@", log: .default, type: .debug, message)
    }
  }
}

enum FluxTunnelError: Error {
  case missingConfig
  case noTunnelFileDescriptor
  case notImplemented
}

/// Разбор итераторов `LibboxRoutePrefixIteratorProtocol`/адресов в структуры
/// `NetworkExtension` — libbox отдаёт их в виде Go-side итераторов
/// (`hasNext`/`next`), а не готовых массивов.
enum FluxRouteHelpers {
  static func hasAny(_ iterator: LibboxRoutePrefixIteratorProtocol) -> Bool {
    iterator.hasNext()
  }

  static func addresses(from iterator: LibboxRoutePrefixIteratorProtocol?) -> [String] {
    var result: [String] = []
    guard let iterator else { return result }
    while iterator.hasNext(), let prefix = iterator.next() {
      result.append(prefix.address())
    }
    return result
  }

  static func masks(from iterator: LibboxRoutePrefixIteratorProtocol?) -> [String] {
    var result: [String] = []
    guard let iterator else { return result }
    while iterator.hasNext(), let prefix = iterator.next() {
      result.append(prefix.mask())
    }
    return result
  }

  static func prefixLengths(from iterator: LibboxRoutePrefixIteratorProtocol?) -> [NSNumber] {
    var result: [NSNumber] = []
    guard let iterator else { return result }
    while iterator.hasNext(), let prefix = iterator.next() {
      result.append(NSNumber(value: prefix.prefix()))
    }
    return result
  }

  static func routes(from iterator: LibboxRoutePrefixIteratorProtocol?) -> [NEIPv4Route] {
    var result: [NEIPv4Route] = []
    guard let iterator else { return result }
    while iterator.hasNext(), let prefix = iterator.next() {
      result.append(NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask()))
    }
    return result
  }

  static func ipv6Routes(from iterator: LibboxRoutePrefixIteratorProtocol?) -> [NEIPv6Route] {
    var result: [NEIPv6Route] = []
    guard let iterator else { return result }
    while iterator.hasNext(), let prefix = iterator.next() {
      result.append(
        NEIPv6Route(
          destinationAddress: prefix.address(),
          networkPrefixLength: NSNumber(value: prefix.prefix())
        )
      )
    }
    return result
  }
}
