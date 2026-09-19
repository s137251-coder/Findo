import 'package:findo/managers/monetization_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _unitsGroup();

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

/// Which ad units a build reaches for.
///
/// Real units are Findo's own, and an impression from a test device is the
/// pattern AdMob suspends accounts over -- so the switch matters more than its
/// size suggests.
void _unitsGroup() {
  group('AdUnitIds', () {
    test('a plain test run never touches the real units', () {
      // No --dart-define here, and a test is not a release build, so both of
      // the conditions that would reach for Findo's own units are absent.
      expect(AdUnitIds.useTestUnits, isFalse,
          reason: 'FINDO_TEST_ADS must be off unless a build asks for it');
      expect(AdUnitIds.interstitial, startsWith('ca-app-pub-3940256099942544/'),
          reason: 'that prefix is Google\'s public test publisher');
      expect(AdUnitIds.rewarded, startsWith('ca-app-pub-3940256099942544/'));
    });

    test('the two units are not the same one', () {
      expect(AdUnitIds.interstitial, isNot(AdUnitIds.rewarded));
    });
  });
}
