import 'package:flutter_test/flutter_test.dart';
import 'package:flux/features/servers/hysteria2_link_parser.dart';

void main() {
  test('parses a hysteria2:// link with obfs and insecure', () {
    final parsed = parseHysteria2Link(
      'hysteria2://secret-password@de1.example.com:443'
      '?insecure=1&obfs=salamander&obfs-password=obfs-secret&sni=de1.example.com'
      '#Germany%201',
    );

    expect(parsed.name, 'Germany 1');
    expect(parsed.config.address, 'de1.example.com');
    expect(parsed.config.port, 443);
    expect(parsed.config.auth, 'secret-password');
    expect(parsed.config.sni, 'de1.example.com');
    expect(parsed.config.insecure, isTrue);
    expect(parsed.config.obfsPassword, 'obfs-secret');
  });

  test('hy2:// alias without obfs leaves obfsPassword null', () {
    final parsed = parseHysteria2Link(
      'hy2://secret-password@de1.example.com:443',
    );

    expect(parsed.name, 'de1.example.com');
    expect(parsed.config.insecure, isFalse);
    expect(parsed.config.obfsPassword, isNull);
  });

  test('rejects a link with no password', () {
    expect(
      () => parseHysteria2Link('hysteria2://@de1.example.com:443'),
      throwsA(isA<Hysteria2LinkFormatException>()),
    );
  });

  test('rejects a non-hysteria2 scheme', () {
    expect(
      () => parseHysteria2Link('vless://uuid@de1.example.com:443'),
      throwsA(isA<Hysteria2LinkFormatException>()),
    );
  });
}
