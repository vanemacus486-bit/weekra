import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/features/updater/domain/app_update.dart';

void main() {
  test('detects newer semantic versions', () {
    expect(isNewerVersion('0.2.0', '0.1.9'), isTrue);
    expect(isNewerVersion('v1.0.0', '0.9.9'), isTrue);
    expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
  });

  test('orders prerelease versions before stable releases', () {
    expect(isNewerVersion('1.0.0', '1.0.0-beta.2'), isTrue);
    expect(isNewerVersion('1.0.0-beta.2', '1.0.0-beta.1'), isTrue);
    expect(isNewerVersion('1.0.0-beta.1', '1.0.0'), isFalse);
  });

  test('rejects malformed versions', () {
    expect(isNewerVersion('latest', '1.0.0'), isFalse);
    expect(isNewerVersion('1.2.3.4', '1.0.0'), isFalse);
  });
}
