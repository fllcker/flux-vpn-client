import 'package:flutter_test/flutter_test.dart';
import 'package:flux/features/servers/derive_server_icon.dart';

void main() {
  test('extracts a flag from a leading ISO country code', () {
    final result = deriveServerIcon('DE Basic - Germany 1');
    expect(result.icon, '🇩🇪');
    expect(result.name, 'Basic - Germany 1');
  });

  test('accepts a hyphen separator too', () {
    final result = deriveServerIcon('NL-Amsterdam');
    expect(result.icon, '🇳🇱');
    expect(result.name, 'Amsterdam');
  });

  test('leaves names without a valid country-code prefix untouched', () {
    expect(deriveServerIcon('Germany #1').icon, isNull);
    expect(deriveServerIcon('Germany #1').name, 'Germany #1');
    // "XX" looks like a code shape but isn't a real ISO 3166-1 alpha-2 code.
    expect(deriveServerIcon('XX Fake Country').icon, isNull);
  });
}
