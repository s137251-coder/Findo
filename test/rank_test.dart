import 'package:findo/models/rank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rank', () {
    test('divides the hundred levels into ten even bands', () {
      expect(Rank.forLevel(1).number, 1);
      expect(Rank.forLevel(10).number, 1);
      expect(Rank.forLevel(11).number, 2);
      expect(Rank.forLevel(41).number, 5);
      expect(Rank.forLevel(100).number, 10);
    });

    test('never runs off the end of the ladder', () {
      expect(Rank.forLevel(0).number, 1);
      expect(Rank.forLevel(-5).number, 1);
      expect(Rank.forLevel(250).number, Rank.count);
    });

    test('reports the levels it covers', () {
      expect(Rank(1).firstLevel, 1);
      expect(Rank(1).lastLevel, 10);
      expect(Rank(7).firstLevel, 61);
      expect(Rank(7).lastLevel, 70);
    });

    test('no rank before the first band is finished', () {
      for (final unlocked in [0, 1, 2, 5, 10]) {
        expect(Rank.earnedBy(unlocked), isNull,
            reason: 'unlocked $unlocked is still inside the first ten');
      }
    });

    test('the first rank is earned by clearing level ten', () {
      // Clearing 10 opens 11.
      expect(Rank.earnedBy(11), const Rank(1));
      expect(Rank.earnedBy(20), const Rank(1));
      expect(Rank.earnedBy(21), const Rank(2));
      expect(Rank.earnedBy(91), const Rank(9));
    });

    test('finishing the last band earns the last rank', () {
      expect(Rank.earnedBy(101), const Rank(10));
      expect(Rank.earnedBy(500), const Rank(10));
    });

    test('names and blurbs point at translation keys', () {
      expect(const Rank(3).nameKey, 'chapter.3.name');
      expect(const Rank(3).blurbKey, 'chapter.3.blurb');
    });
  });
}
