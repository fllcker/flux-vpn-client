import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/geo_dat_format.dart';

/// Ручной protobuf-энкодер — используется только тут, чтобы собрать
/// маленькие валидные фикстуры без реального `.dat`-файла на диске (см.
/// `geo_dat_format.dart` — сам формат описан там).
class _Writer {
  final _bytes = BytesBuilder();

  void varint(int value) {
    var v = value;
    while (true) {
      if (v & ~0x7f == 0) {
        _bytes.addByte(v);
        return;
      }
      _bytes.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
  }

  void tag(int fieldNumber, int wireType) => varint((fieldNumber << 3) | wireType);

  void lengthDelimited(int fieldNumber, List<int> payload) {
    tag(fieldNumber, 2);
    varint(payload.length);
    _bytes.add(payload);
  }

  void stringField(int fieldNumber, String value) =>
      lengthDelimited(fieldNumber, value.codeUnits);

  void varintField(int fieldNumber, int value) {
    tag(fieldNumber, 0);
    varint(value);
  }

  Uint8List toBytes() => _bytes.toBytes();
}

Uint8List _domainBytes(int type, String value) {
  final w = _Writer();
  w.varintField(1, type);
  w.stringField(2, value);
  return w.toBytes();
}

Uint8List _geoSiteBytes(String countryCode, List<Uint8List> domains) {
  final w = _Writer();
  w.stringField(1, countryCode);
  for (final d in domains) {
    w.lengthDelimited(2, d);
  }
  return w.toBytes();
}

Uint8List _geoSiteListBytes(List<Uint8List> entries) {
  final w = _Writer();
  for (final e in entries) {
    w.lengthDelimited(1, e);
  }
  return w.toBytes();
}

Uint8List _cidrBytes(List<int> ip, int prefix) {
  final w = _Writer();
  w.lengthDelimited(1, ip);
  w.varintField(2, prefix);
  return w.toBytes();
}

Uint8List _geoIpBytes(String countryCode, List<Uint8List> cidrs) {
  final w = _Writer();
  w.stringField(1, countryCode);
  for (final c in cidrs) {
    w.lengthDelimited(2, c);
  }
  return w.toBytes();
}

Uint8List _geoIpListBytes(List<Uint8List> entries) {
  final w = _Writer();
  for (final e in entries) {
    w.lengthDelimited(1, e);
  }
  return w.toBytes();
}

void main() {
  group('parseGeoSiteDat', () {
    test('parses country code and mixed domain types', () {
      final bytes = _geoSiteListBytes([
        _geoSiteBytes('category-ads', [
          _domainBytes(0, 'ads.example'), // Plain
          _domainBytes(2, 'example.com'), // Domain (+ subdomains)
          _domainBytes(3, 'exact.example.com'), // Full
          _domainBytes(1, '^ad[0-9]+\\.'), // Regex
        ]),
      ]);

      final entries = parseGeoSiteDat(bytes);

      expect(entries, hasLength(1));
      expect(entries.single.countryCode, 'category-ads');
      expect(entries.single.domains, hasLength(4));
      expect(entries.single.domains[0].type, GeoDomainType.plain);
      expect(entries.single.domains[0].value, 'ads.example');
      expect(entries.single.domains[1].type, GeoDomainType.domain);
      expect(entries.single.domains[1].value, 'example.com');
      expect(entries.single.domains[2].type, GeoDomainType.full);
      expect(entries.single.domains[3].type, GeoDomainType.regex);
    });

    test('parses multiple entries', () {
      final bytes = _geoSiteListBytes([
        _geoSiteBytes('cn', [_domainBytes(2, 'a.cn')]),
        _geoSiteBytes('ru', [_domainBytes(2, 'a.ru')]),
      ]);

      final entries = parseGeoSiteDat(bytes);

      expect(entries.map((e) => e.countryCode), ['cn', 'ru']);
    });
  });

  group('findGeoSiteCategory', () {
    test('matches case-insensitively', () {
      final entries = parseGeoSiteDat(
        _geoSiteListBytes([
          _geoSiteBytes('CATEGORY-ADS', [_domainBytes(2, 'ads.example')]),
        ]),
      );

      final found = findGeoSiteCategory(entries, 'category-ads');
      expect(found.countryCode, 'CATEGORY-ADS');
    });

    test('throws GeoCategoryNotFoundException when missing', () {
      final entries = parseGeoSiteDat(_geoSiteListBytes([]));
      expect(
        () => findGeoSiteCategory(entries, 'missing'),
        throwsA(isA<GeoCategoryNotFoundException>()),
      );
    });
  });

  group('parseGeoIpDat', () {
    test('parses IPv4 and IPv6 CIDR entries', () {
      final bytes = _geoIpListBytes([
        _geoIpBytes('cn', [
          _cidrBytes([1, 2, 3, 0], 24),
          _cidrBytes(
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            128,
          ), // ::1
        ]),
      ]);

      final entries = parseGeoIpDat(bytes);

      expect(entries, hasLength(1));
      expect(entries.single.countryCode, 'cn');
      expect(entries.single.cidrs[0].cidr, '1.2.3.0/24');
      expect(entries.single.cidrs[1].cidr, '::1/128');
    });
  });

  group('findGeoIpCategory', () {
    test('throws GeoCategoryNotFoundException when missing', () {
      final entries = parseGeoIpDat(_geoIpListBytes([]));
      expect(
        () => findGeoIpCategory(entries, 'cn'),
        throwsA(isA<GeoCategoryNotFoundException>()),
      );
    });
  });
}
