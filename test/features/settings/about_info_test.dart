import 'package:flutter_test/flutter_test.dart';
import 'package:flux/features/settings/about_info.dart';

void main() {
  // Строки взяты дословно из вывода тех бинарников, что лежат в assets/.
  test('parseCoreVersion reads sing-box output', () {
    expect(parseCoreVersion('sing-box version 1.13.14\n'), '1.13.14');
  });

  test('parseCoreVersion reads xray output, which has no "version" word', () {
    const output =
        'Xray 26.3.27 (Xray, Penetrates Everything.) d2758a0 (go1.26.1 windows/amd64)\n'
        'A unified platform for anti-censorship.\n';

    // Не 1.26.1 из версии Go в конце той же строки.
    expect(parseCoreVersion(output), '26.3.27');
  });

  test('parseCoreVersion returns null instead of a bogus version', () {
    expect(parseCoreVersion(''), isNull);
    expect(parseCoreVersion('\n  \n'), isNull);
    expect(parseCoreVersion('command not found'), isNull);
  });
}
