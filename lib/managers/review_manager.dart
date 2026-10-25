import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import 'save_manager.dart';

/// Asking for a rating, and the Settings button that rates on purpose.
///
/// The ask is Google Play's own in-app review card, which a player can answer
/// without leaving the game. It comes after a clear that went well -- two
/// stars or better -- at a few milestones, never on a first level and never
/// twice at the same one. Play decides on its own whether the card actually
/// appears and caps how often, so asking a little too often costs nothing,
/// while asking at a bad moment costs the rating.
class ReviewManager {
  ReviewManager(this._save, {InAppReview? review})
      : _review = review ?? InAppReview.instance;

  final SaveManager _save;
  final InAppReview _review;

  /// The clears that ask: early enough that most players reach the first,
  /// spread out so a player who said nothing is asked again a good while
  /// later.
  static const milestones = [3, 8, 20, 45, 80];

  /// Whether clearing [levelIndex] with [stars] should ask for a rating.
  bool isDue({required int levelIndex, required int stars}) =>
      shouldAsk(
        levelIndex: levelIndex,
        stars: stars,
        alreadyAskedAt: _save.reviewAskedAtLevel,
      );

  /// The rule on its own, so it can be tested without a phone.
  @visibleForTesting
  static bool shouldAsk({
    required int levelIndex,
    required int stars,
    required int alreadyAskedAt,
  }) {
    if (stars < 2 || levelIndex <= alreadyAskedAt) {
      return false;
    }
    // A milestone reached, or passed while the player was not doing well
    // enough to be asked: the next good clear after it takes its place.
    return milestones.any(
      (milestone) => milestone <= levelIndex && milestone > alreadyAskedAt,
    );
  }

  /// Shows Play's review card. Recorded first, so a card that fails to show
  /// is not retried on every clear after it.
  Future<void> ask(int levelIndex) async {
    await _save.setReviewAskedAtLevel(levelIndex);
    try {
      if (await _review.isAvailable()) {
        await _review.requestReview();
      }
    } catch (error) {
      _log('review card unavailable: $error');
    }
  }

  /// Opens Findo's store page at the reviews, from Settings.
  ///
  /// Not the in-app card: a player who pressed "Rate" should always get
  /// somewhere, and the card is allowed to silently not appear.
  Future<void> openStorePage() async {
    try {
      await _review.openStoreListing();
    } catch (error) {
      _log('store page unavailable: $error');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[review] $message');
    }
  }
}
