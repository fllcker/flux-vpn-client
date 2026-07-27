/// Ручной декодер protobuf-wire-формата `geosite.dat`/`geoip.dat`
/// (v2ray/xray-core, https://github.com/v2fly/domain-list-community и
/// https://github.com/Loyalsoldier/v2ray-rules-dat) — см. ROADMAP.md, трек
/// 21. Схема обоих файлов простая (`GeoSiteList`/`GeoIPList` — плоские
/// списки записей по коду страны/категории), так что полноценный
/// protobuf-пакет не подключаем, а читаем wire-формат вручную: varint +
/// length-delimited, без зависимостей.
///
/// Схемы (proto3, для справки — не парсятся из .proto, а зашиты руками):
/// ```proto
/// message GeoSiteList { repeated GeoSite entry = 1; }
/// message GeoSite {
///   string country_code = 1;
///   repeated Domain domain = 2;
/// }
/// message Domain {
///   enum Type { Plain = 0; Regex = 1; Domain = 2; Full = 3; }
///   Type type = 1;
///   string value = 2;
/// }
///
/// message GeoIPList { repeated GeoIP entry = 1; }
/// message GeoIP {
///   string country_code = 1;
///   repeated CIDR cidr = 2;
/// }
/// message CIDR { bytes ip = 1; uint32 prefix = 2; }
/// ```
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum GeoDomainType { plain, regex, domain, full }

class GeoDomainEntry {
  final GeoDomainType type;
  final String value;
  const GeoDomainEntry(this.type, this.value);
}

class GeoSiteEntry {
  final String countryCode;
  final List<GeoDomainEntry> domains;
  const GeoSiteEntry(this.countryCode, this.domains);
}

class GeoCidrEntry {
  /// Строковое представление адреса (`1.2.3.0`/`::1`), уже без маски.
  final String ip;
  final int prefix;
  const GeoCidrEntry(this.ip, this.prefix);

  /// `ip/prefix` — формат, который xray/sing-box ожидают в `ip_cidr`.
  String get cidr => '$ip/$prefix';
}

class GeoIpEntry {
  final String countryCode;
  final List<GeoCidrEntry> cidrs;
  const GeoIpEntry(this.countryCode, this.cidrs);
}

/// Правило роутинга ссылается на категорию, которой нет в `.dat`-файле —
/// это ошибка конфигурации сервиса (сервер прописал `geosite:xxx`, которого
/// нет в базе), не повод тихо no-op'нуть правило.
class GeoCategoryNotFoundException implements Exception {
  final String category;
  const GeoCategoryNotFoundException(this.category);

  @override
  String toString() => 'geosite/geoip category not found: $category';
}

List<GeoSiteEntry> parseGeoSiteDat(Uint8List bytes) {
  final reader = _ProtoReader(bytes);
  final entries = <GeoSiteEntry>[];
  while (reader.hasMore) {
    final tag = reader.readTag();
    if (tag.fieldNumber == 1 && tag.wireType == _WireType.lengthDelimited) {
      entries.add(_parseGeoSite(reader.readLengthDelimited()));
    } else {
      reader.skip(tag.wireType);
    }
  }
  return entries;
}

List<GeoIpEntry> parseGeoIpDat(Uint8List bytes) {
  final reader = _ProtoReader(bytes);
  final entries = <GeoIpEntry>[];
  while (reader.hasMore) {
    final tag = reader.readTag();
    if (tag.fieldNumber == 1 && tag.wireType == _WireType.lengthDelimited) {
      entries.add(_parseGeoIp(reader.readLengthDelimited()));
    } else {
      reader.skip(tag.wireType);
    }
  }
  return entries;
}

GeoSiteEntry findGeoSiteCategory(List<GeoSiteEntry> entries, String category) {
  for (final entry in entries) {
    if (entry.countryCode.toLowerCase() == category.toLowerCase()) return entry;
  }
  throw GeoCategoryNotFoundException(category);
}

GeoIpEntry findGeoIpCategory(List<GeoIpEntry> entries, String category) {
  for (final entry in entries) {
    if (entry.countryCode.toLowerCase() == category.toLowerCase()) return entry;
  }
  throw GeoCategoryNotFoundException(category);
}

GeoSiteEntry _parseGeoSite(Uint8List bytes) {
  final reader = _ProtoReader(bytes);
  var countryCode = '';
  final domains = <GeoDomainEntry>[];
  while (reader.hasMore) {
    final tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 1:
        countryCode = _utf8(reader.readLengthDelimited());
      case 2:
        domains.add(_parseDomain(reader.readLengthDelimited()));
      default:
        reader.skip(tag.wireType);
    }
  }
  return GeoSiteEntry(countryCode, domains);
}

GeoDomainEntry _parseDomain(Uint8List bytes) {
  final reader = _ProtoReader(bytes);
  var type = GeoDomainType.plain;
  var value = '';
  while (reader.hasMore) {
    final tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 1:
        type = _domainType(reader.readVarint());
      case 2:
        value = _utf8(reader.readLengthDelimited());
      default:
        reader.skip(tag.wireType);
    }
  }
  return GeoDomainEntry(type, value);
}

GeoDomainType _domainType(int raw) => switch (raw) {
  1 => GeoDomainType.regex,
  2 => GeoDomainType.domain,
  3 => GeoDomainType.full,
  _ => GeoDomainType.plain,
};

GeoIpEntry _parseGeoIp(Uint8List bytes) {
  final reader = _ProtoReader(bytes);
  var countryCode = '';
  final cidrs = <GeoCidrEntry>[];
  while (reader.hasMore) {
    final tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 1:
        countryCode = _utf8(reader.readLengthDelimited());
      case 2:
        cidrs.add(_parseCidr(reader.readLengthDelimited()));
      default:
        reader.skip(tag.wireType);
    }
  }
  return GeoIpEntry(countryCode, cidrs);
}

GeoCidrEntry _parseCidr(Uint8List bytes) {
  final reader = _ProtoReader(bytes);
  Uint8List ip = Uint8List(0);
  var prefix = 0;
  while (reader.hasMore) {
    final tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 1:
        ip = reader.readLengthDelimited();
      case 2:
        prefix = reader.readVarint();
      default:
        reader.skip(tag.wireType);
    }
  }
  return GeoCidrEntry(InternetAddress.fromRawAddress(ip).address, prefix);
}

String _utf8(Uint8List bytes) => utf8.decode(bytes);

enum _WireType { varint, fixed64, lengthDelimited, fixed32 }

class _Tag {
  final int fieldNumber;
  final _WireType wireType;
  const _Tag(this.fieldNumber, this.wireType);
}

class _ProtoReader {
  final Uint8List _bytes;
  int _pos = 0;

  _ProtoReader(this._bytes);

  bool get hasMore => _pos < _bytes.length;

  _Tag readTag() {
    final key = readVarint();
    final fieldNumber = key >> 3;
    final wireType = switch (key & 0x7) {
      0 => _WireType.varint,
      1 => _WireType.fixed64,
      2 => _WireType.lengthDelimited,
      5 => _WireType.fixed32,
      final other => throw FormatException('Unknown protobuf wire type $other'),
    };
    return _Tag(fieldNumber, wireType);
  }

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final byte = _bytes[_pos++];
      result |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) break;
      shift += 7;
    }
    return result;
  }

  Uint8List readLengthDelimited() {
    final length = readVarint();
    final result = Uint8List.sublistView(_bytes, _pos, _pos + length);
    _pos += length;
    return result;
  }

  void skip(_WireType wireType) {
    switch (wireType) {
      case _WireType.varint:
        readVarint();
      case _WireType.lengthDelimited:
        readLengthDelimited();
      case _WireType.fixed64:
        _pos += 8;
      case _WireType.fixed32:
        _pos += 4;
    }
  }
}
