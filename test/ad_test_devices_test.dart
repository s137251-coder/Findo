import 'package:findo/managers/monetization_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdTestDevices.parse', () {
    test('returns nothing for an unset or blank define', () {
      expect(AdTestDevices.parse(''), isEmpty);
      expect(AdTestDevices.parse('   '), isEmpty);
      expect(AdTestDevices.parse(',,'), isEmpty);
    });

    test('reads one id', () {
      expect(AdTestDevices.parse('33BE2250B43518CCDA7DE426D04EE231'),
          ['33BE2250B43518CCDA7DE426D04EE231']);
    });

    test('trims spaces and drops the empty slot a trailing comma leaves', () {
      // What a build command actually looks like after someone pastes ids in.
      expect(AdTestDevices.parse(' ABC , DEF, '), ['ABC', 'DEF']);
    });

    test('de-duplicates, because the SDK rejects a repeated id', () {
      expect(AdTestDevices.parse('ABC,DEF,ABC'), ['ABC', 'DEF']);
    });
  });
}
