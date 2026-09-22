import 'dart:math';

/// The name a player appears under on the leaderboard.
///
/// Nobody types this. A table that anyone can write their own name into is a
/// table with a slur on it within the week, and it would also mean collecting
/// something a person wrote about themselves -- which is a heavier thing to
/// hold, and to declare, than a name the game made up. So the game picks:
/// an adjective, a creature and a number, in the language the game is being
/// played in.
///
/// Roughly nine hundred thousand of them per language, so two players sharing
/// one is rare, and harmless when it happens -- a player's own row is marked
/// as theirs however it reads.
class PlayerName {
  const PlayerName._();

  /// Hebrew adjectives agree with the gender of the noun, so each one is
  /// carried in both forms and the creature picks which to use. "לטאה סקרן"
  /// is not a name, it is a mistake.
  static const _hebrewAdjectives = <List<String>>[
    ['זריז', 'זריזה'],
    ['סקרן', 'סקרנית'],
    ['חכם', 'חכמה'],
    ['נועז', 'נועזת'],
    ['שקט', 'שקטה'],
    ['ערמומי', 'ערמומית'],
    ['רגוע', 'רגועה'],
    ['עקשן', 'עקשנית'],
    ['נמרץ', 'נמרצת'],
    ['חמקמק', 'חמקמקה'],
    ['אמיץ', 'אמיצה'],
    ['עירני', 'עירנית'],
    ['שובב', 'שובבה'],
    ['מהיר', 'מהירה'],
    ['חד', 'חדה'],
    ['נחוש', 'נחושה'],
    ['קליל', 'קלילה'],
    ['מסתורי', 'מסתורית'],
    ['זהיר', 'זהירה'],
    ['נדיב', 'נדיבה'],
    ['עליז', 'עליזה'],
    ['תותח', 'תותחית'],
    ['סבלני', 'סבלנית'],
    ['פזיז', 'פזיזה'],
    ['חרוץ', 'חרוצה'],
    ['גאה', 'גאה'],
    ['מנומס', 'מנומסת'],
    ['צנוע', 'צנועה'],
    ['נועם', 'נועמת'],
    ['בהיר', 'בהירה'],
  ];

  /// Creatures, each with the gender its Hebrew name takes.
  static const _hebrewCreatures = <List<String>>[
    ['נמר', 'm'],
    ['שועל', 'm'],
    ['ינשוף', 'm'],
    ['דולפין', 'm'],
    ['ברווז', 'm'],
    ['פינגווין', 'm'],
    ['גמל', 'm'],
    ['צבי', 'm'],
    ['אריה', 'm'],
    ['קיפוד', 'm'],
    ['תנשמת', 'f'],
    ['לטאה', 'f'],
    ['חתולה', 'f'],
    ['צבה', 'f'],
    ['סנאית', 'f'],
    ['זברה', 'f'],
    ['נמלה', 'f'],
    ['פרפרה', 'f'],
    ['לביאה', 'f'],
    ['דבורה', 'f'],
    ['חמוס', 'm'],
    ['גירית', 'f'],
    ['קנגורו', 'm'],
    ['תוכי', 'm'],
    ['נחליאלי', 'm'],
    ['שרקן', 'm'],
    ['אייל', 'm'],
    ['לוויתן', 'm'],
    ['עטלף', 'm'],
    ['חוחית', 'f'],
  ];

  static const _englishAdjectives = <String>[
    'Swift', 'Curious', 'Clever', 'Daring', 'Quiet', 'Sly', 'Calm', 'Stubborn',
    'Eager', 'Elusive', 'Brave', 'Alert', 'Playful', 'Rapid', 'Sharp',
    'Determined', 'Nimble', 'Mysterious', 'Careful', 'Generous', 'Cheerful',
    'Mighty', 'Patient', 'Restless', 'Diligent', 'Proud', 'Polite', 'Modest',
    'Gentle', 'Bright',
  ];

  static const _englishCreatures = <String>[
    'Tiger', 'Fox', 'Owl', 'Dolphin', 'Duck', 'Penguin', 'Camel', 'Deer',
    'Lion', 'Hedgehog', 'Barn Owl', 'Lizard', 'Cat', 'Turtle', 'Squirrel',
    'Zebra', 'Ant', 'Butterfly', 'Lioness', 'Bee', 'Weasel', 'Badger',
    'Kangaroo', 'Parrot', 'Wagtail', 'Marmot', 'Elk', 'Whale', 'Bat', 'Finch',
  ];

  /// The smallest and largest number a name can carry. Three digits, because
  /// two would put a dozen players a thousand on the same name.
  static const _lowestNumber = 100;
  static const _highestNumber = 999;

  /// A fresh name in [languageCode], which is 'he' for Hebrew and anything
  /// else for English.
  ///
  /// The language is the one the game is in when the name is first made, and
  /// it stays: a player who has been "נמר סקרן 147" on the table for a month
  /// should not become someone else because they changed the app's language.
  static String create(String languageCode, {Random? random}) {
    final pick = random ?? Random();
    final number = _lowestNumber +
        pick.nextInt(_highestNumber - _lowestNumber + 1);
    if (languageCode == 'he') {
      final creature = _hebrewCreatures[pick.nextInt(_hebrewCreatures.length)];
      final adjective =
          _hebrewAdjectives[pick.nextInt(_hebrewAdjectives.length)];
      final agreeing = creature[1] == 'f' ? adjective[1] : adjective[0];
      return '${creature[0]} $agreeing $number';
    }
    final creature = _englishCreatures[pick.nextInt(_englishCreatures.length)];
    final adjective = _englishAdjectives[pick.nextInt(_englishAdjectives.length)];
    return '$adjective $creature $number';
  }

  /// Whether [name] is one this generator could actually have made.
  ///
  /// Not "does it look about right": the words have to be in the lists above,
  /// in the right order, with a Hebrew adjective agreeing with its creature.
  /// Checking the shape alone would pass anything spelled in letters -- an
  /// insult, or an advertisement -- onto a table every player can see, which
  /// is exactly what a modified client would write there.
  ///
  /// The rules on the server say the same thing, generated from these same
  /// lists, because a check that only runs in the app protects nothing.
  static bool isWellFormed(String name) {
    if (name.length > 40 || name.trim() != name) {
      return false;
    }
    final parts = name.split(' ');
    if (parts.length < 3) {
      return false;
    }
    final digits = parts.last;
    final number = int.tryParse(digits);
    if (number == null ||
        digits.length != 3 ||
        number < _lowestNumber ||
        number > _highestNumber) {
      return false;
    }
    final words = parts.sublist(0, parts.length - 1).join(' ');

    // Hebrew puts the creature first.
    for (final creature in _hebrewCreatures) {
      if (words.startsWith('${creature[0]} ')) {
        final adjective = words.substring(creature[0].length + 1);
        final form = creature[1] == 'f' ? 1 : 0;
        return _hebrewAdjectives.any((pair) => pair[form] == adjective);
      }
    }
    // English puts it second, and some creatures are two words.
    for (final adjective in _englishAdjectives) {
      if (words.startsWith('$adjective ')) {
        return _englishCreatures.contains(
          words.substring(adjective.length + 1),
        );
      }
    }
    return false;
  }

  /// How many different names a language can make, for the record.
  static int get variety =>
      _hebrewAdjectives.length *
      _hebrewCreatures.length *
      (_highestNumber - _lowestNumber + 1);
}
