import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../game/findo_game.dart';
import '../managers/audio_manager.dart';
import '../managers/localization_manager.dart';
import '../managers/score_manager.dart';
import '../models/daily_hunt.dart';
import '../models/level_definition.dart';
import 'character_sheet_modal.dart';
import 'daily_hunt_ui.dart';
import 'finale_screen.dart';
import 'hint_dialog.dart';
import 'leaderboard_screen.dart';
import '../models/rank.dart';
import 'hud_overlay.dart';
import 'rank_screen.dart';
import 'pause_modal.dart';
import 'reminder_prompt.dart';
import 'share.dart';
import 'tutorial_overlay.dart';
import 'win_modal.dart';

/// Hosts the Flame canvas and every Flutter overlay drawn on top of it.
///
/// The Flame side never navigates: it reports "cleared" or "time up", and this
/// widget decides which overlay to raise and what to persist.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.level,
    this.daily,
    this.tutorial = false,
  });

  final LevelDefinition level;

  /// Runs the guided first hunt on this level even for a player who has
  /// already had it -- asked for from the rules screen.
  final bool tutorial;

  /// Set for the daily hunt: a fixed hiding place, no hints, and a time for
  /// the table instead of stars and progress.
  final DailyHunt? daily;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final AppServices _services;
  late final ScoreManager _scoreManager;
  late FindoGame _game;

  /// False until [_startLevel] has built the first game, so the level being
  /// replaced can be told apart from there being no level yet.
  bool _hasGame = false;

  LevelResult? _result;

  /// Stars banked across every level after this clear, and the free hints the
  /// clear paid for. Shown in the summary.
  int _totalStars = 0;
  int _starHints = 0;

  /// Set when clearing this level earned a new rank, so the ceremony can run
  /// after the score summary rather than on top of it.
  Rank? _pendingRank;

  /// Set when this clear was the last level of the last rank: the ending is
  /// owed, and runs after the summary and the promotion rather than between
  /// them.
  bool _pendingFinale = false;

  /// The level that ends the game.
  static const _finaleLevel = Rank.count * Rank.levelsPerRank;

  /// Plays the ending after any clear, so it can be seen before a hundred
  /// levels exist:
  ///   flutter build apk --dart-define=FINDO_FINALE_DEMO=true
  static const _finaleDemo = bool.fromEnvironment('FINDO_FINALE_DEMO');
  bool _servicesReady = false;

  /// The daily hunt's first attempt of the day, the one that is posted.
  bool _officialAttempt = false;

  /// How the daily hunt just went, for its result panel.
  DailyOutcome? _dailyOutcome;

  /// The guided first hunt, while it is running.
  TutorialController? _tutorial;

  /// The tip on screen now, if any.
  String? _tipKey;

  /// Set by a clear that should ask for a rating, which happens on the way
  /// out of the summary instead of the interstitial.
  bool _reviewDue = false;

  /// One-off tips and the level each first becomes useful on. Shown once
  /// each, one per level start, so a player who updates mid-game meets them
  /// one at a time too.
  static const _levelTips = {
    2: 'tip.timeBonus',
    3: 'tip.character',
    4: 'tip.daily',
    6: 'tip.zoom',
    8: 'tip.stars',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servicesReady) {
      return;
    }
    _services = AppServices.of(context);
    _servicesReady = true;
    _scoreManager = ScoreManager();
    final daily = widget.daily;
    if (daily != null) {
      _officialAttempt = !_services.save.dailyStarted(daily.day);
      if (_officialAttempt) {
        unawaited(_services.save.markDailyStarted(daily.day));
      }
    }
    final firstHunt = !_services.save.tutorialDone &&
        widget.level.index == 1 &&
        _services.save.unlockedLevelIndex <= 1;
    if (daily == null && (widget.tutorial || firstHunt)) {
      _tutorial = TutorialController()..addListener(_onTutorialChanged);
    }
    _startLevel(widget.level);
  }

  /// Lets the clock run, and remembers, once the guided hunt is over --
  /// finished or skipped.
  void _onTutorialChanged() {
    final tutorial = _tutorial;
    if (tutorial == null || tutorial.active) {
      return;
    }
    _game.clockHeld = false;
    unawaited(_services.save.setTutorialDone(true));
  }

  /// Puts up the tip for this level, if one is due.
  void _offerLevelTip(LevelDefinition level) {
    if (widget.daily != null || (_tutorial?.active ?? false)) {
      return;
    }
    final seen = _services.save.tipsSeen;
    for (final entry in _levelTips.entries) {
      if (level.index >= entry.key && !seen.contains(entry.value)) {
        _showTip(entry.value);
        return;
      }
    }
  }

  void _showTip(String key) {
    unawaited(_services.save.markTipSeen(key));
    _tipKey = key;
    _game.overlays.remove(TipBanner.overlayId);
    _game.overlays.add(TipBanner.overlayId);
  }

  void _hideTip() {
    _game.overlays.remove(TipBanner.overlayId);
    _tipKey = null;
  }

  /// The first wrong tap ever is when the cost of one is worth explaining.
  void _onMisclick() {
    const key = 'tip.misclick';
    // The guided hunt's last card says this already, and the two would sit
    // on top of each other.
    if (_tutorial?.active ?? false) {
      return;
    }
    if (!_services.save.tipsSeen.contains(key)) {
      _showTip(key);
    }
  }

  void _startLevel(LevelDefinition chosen) {
    // The daily hunt plays its map at the top of the difficulty curve.
    final level = widget.daily == null ? chosen : DailyHunt.harden(chosen);
    _services.levels.startLevel(level);
    _scoreManager.startLevel(level);
    // A track picked at random from assets/audio/music, looped until the
    // level ends. One loop across every level is what wore the old music out.
    unawaited(_services.audio.startRandomMusic());
    _result = null;
    final outgoing = _hasGame ? _game : null;
    _game = FindoGame(
      level: level,
      // Picked per attempt, so replaying a level is another search -- except
      // in the daily hunt, where everyone looks in the same place.
      target: widget.daily == null
          ? _services.levels.pickTarget(level)
          : level.targets[widget.daily!.spotSeed % level.targets.length],
      scoreManager: _scoreManager,
      levelManager: _services.levels,
      audioManager: _services.audio,
      onLevelCleared: _handleLevelCleared,
      onTimeUp: _handleTimeUp,
    )
      ..clockHeld = _tutorial?.active ?? false
      ..onPlayerPanned = (() => _tutorial?.did(TutorialStep.drag))
      ..onPlayerZoomed = (() => _tutorial?.did(TutorialStep.zoom))
      ..onMisclick = _onMisclick;
    _hasGame = true;
    _offerLevelTip(level);
    _releaseMap(outgoing, keep: level.map);
  }

  /// Gives back the map the finished level was holding.
  ///
  /// Flame hands every game the same global image cache and nothing ever
  /// clears it, so each level played left its map decoded for the rest of the
  /// session: 6 MB for a 1254px map, 17 for a 2048px one. Fifteen levels into
  /// a run that is a couple of hundred megabytes of pictures nobody will look
  /// at again, which is what made the later levels stutter and then freeze.
  ///
  /// [keep] is the map the level starting now needs. Replaying a level asks
  /// for the same picture, and disposing it here would pull it out from under
  /// the game that is about to draw it.
  void _releaseMap(FindoGame? outgoing, {required String keep}) {
    if (outgoing == null || outgoing.level.map == keep) {
      return;
    }
    final map = outgoing.level.map;
    // After this frame, when the old game is off the widget tree: an image
    // disposed while something is still drawing it takes the game down.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => outgoing.images.clear(map),
    );
  }

  @override
  void dispose() {
    // Leaving for the level list ends the last level too, and its map goes
    // back the same way.
    if (_hasGame) {
      _game.images.clear(_game.level.map);
    }
    // The music belonged to the hunt, and the hunt is over. Without this it
    // carried on under the level list and the title screen.
    if (_servicesReady) {
      unawaited(_services.audio.endMusic());
    }
    _tutorial?.dispose();
    _scoreManager.dispose();
    super.dispose();
  }

  // -- outcomes ------------------------------------------------------------

  Future<void> _handleLevelCleared() async {
    if (widget.daily != null) {
      return _handleDailyEnd(found: true);
    }
    // Finding her ends the guided hunt wherever it had got to: a player who
    // spotted her before being shown the hint has learned what it was for.
    _tutorial?.skip();
    _hideTip();
    final level = _game.level;
    final projected = _scoreManager.projectedTotal(cleared: true);
    final stars = level.starThresholds.starsFor(projected);
    final isNewBest = await _services.levels.recordResult(
      level: level,
      score: projected,
      stars: stars,
      cleared: true,
    );
    final starHints = await _services.monetization.claimStarHints();
    final result = _scoreManager.finish(
      level: level,
      found: true,
      isNewBest: isNewBest,
    );
    if (!mounted) {
      return;
    }
    // A rank is earned by the level the clear unlocks, and shown once. The
    // summary comes first: the player wants the score they just made before
    // a ceremony about it.
    final earned = Rank.earnedBy(_services.save.unlockedLevelIndex);
    final pending = (earned != null && earned.number > _services.save.rankSeen)
        ? earned
        : null;
    _pendingFinale = (_finaleDemo || level.index >= _finaleLevel) &&
        !_services.save.finaleSeen;
    _reviewDue = !widget.tutorial &&
        _services.review.isDue(levelIndex: level.index, stars: stars);
    setState(() {
      _result = result;
      _pendingRank = pending;
      _totalStars = _services.save.totalStars;
      _starHints = starHints;
    });
    _game.setAccepting(false);
    _game.overlays.add(WinModal.overlayId);
    // The level is over: nothing behind the summary needs another frame.
    _game.pauseEngine();
  }

  Future<void> _handleTimeUp() async {
    if (widget.daily != null) {
      return _handleDailyEnd(found: false);
    }
    _tutorial?.skip();
    _hideTip();
    final level = _game.level;
    await _services.levels.recordResult(
      level: level,
      score: _scoreManager.score,
      stars: 0,
      cleared: false,
    );
    if (!mounted) {
      return;
    }
    _game.setAccepting(false);
    _game.overlays.add(TimeUpModal.overlayId);
    _game.pauseEngine();
  }

  /// Ends a daily hunt: the time (misclick penalties included) is saved and
  /// posted if this was the day's first attempt, and never touches the
  /// level's stars or the player's progress -- the daily level can be one the
  /// player has not unlocked.
  Future<void> _handleDailyEnd({required bool found}) async {
    final elapsed = _scoreManager.timeLimit - _scoreManager.timeRemaining;
    final milliseconds = (elapsed * 1000).round();
    final official = _officialAttempt;
    _officialAttempt = false;
    _game.setAccepting(false);
    setState(() {
      _dailyOutcome = DailyOutcome(
        found: found,
        milliseconds: milliseconds,
        official: official,
        posting: official && found,
      );
    });
    _game.overlays.add(DailyResultPanel.overlayId);
    _game.pauseEngine();
    // Today's hunt is played: tonight's reminder would be for nothing.
    unawaited(_services.reminder.reschedule(
      title: context.l10n.t('reminder.title'),
      body: context.l10n.t('reminder.body'),
    ));
    if (!official) {
      return;
    }
    await _services.save.recordDailyTime(found ? milliseconds : -1);
    if (!found) {
      return;
    }
    final day = widget.daily!.day;
    final posted = await _services.table.submitDailyTime(
      day: day,
      milliseconds: milliseconds,
    );
    final rank = posted ? await _services.table.todaysRank(day) : null;
    if (mounted) {
      setState(() {
        _dailyOutcome = _dailyOutcome?.settled(posted: posted, rank: rank);
      });
    }
  }

  Future<void> _showDailyTable() => openLeaderboard(context);

  // -- navigation ----------------------------------------------------------

  /// Shows the interstitial that is due, then runs [next]. Ads never sit
  /// between the player and the result they just earned, only after it.
  ///
  /// At most one thing stands between the summary and what the player chose:
  /// Play's rating card after a milestone, else the one-time question about
  /// the Daily Hunt reminder, else the interstitial that is due.
  Future<void> _leaveLevel(VoidCallback next) async {
    if (_reviewDue) {
      _reviewDue = false;
      await _services.review.ask(_game.level.index);
    } else if (_shouldOfferReminder) {
      await offerDailyReminder(context, _services);
    } else {
      await _services.monetization.onLevelFinished();
    }
    if (!mounted) {
      return;
    }
    next();
  }

  /// Once, after the second level is cleared: by then the player has seen
  /// enough of the game to know whether they want to hear from it.
  bool get _shouldOfferReminder =>
      widget.daily == null &&
      _services.reminder.supported &&
      !_services.save.reminderAsked &&
      _services.save.unlockedLevelIndex >= 3;

  void _shareLevel(LevelResult result) {
    final l10n = context.l10n;
    unawaited(shareText(
      context,
      l10n.t('share.level', params: {
        'seconds': result.secondsTaken,
        'level': _game.level.index,
        'stars': result.stars,
      }),
    ));
  }

  void _shareDaily(DailyOutcome outcome) {
    final l10n = context.l10n;
    unawaited(shareText(
      context,
      outcome.found
          ? l10n.t('share.daily', params: {
              'time': formatDailyTime(outcome.milliseconds),
            })
          : l10n.t('share.dailyMissed'),
    ));
  }

  /// Runs the promotion first when one is due, then whatever the button meant.
  void _afterRank(VoidCallback next) {
    final rank = _pendingRank;
    if (rank == null) {
      _finaleOr(next);
      return;
    }
    _rankThen = () => _finaleOr(next);
    unawaited(_services.save.setRankSeen(rank.number));
    unawaited(_services.audio.playPromotion());
    _game.overlays.remove(WinModal.overlayId);
    _game.overlays.add(RankScreen.overlayId);
  }

  VoidCallback? _rankThen;

  /// The ending takes over from whichever button the player pressed: it is
  /// owed to them however they chose to leave the last level.
  void _finaleOr(VoidCallback next) {
    if (!_pendingFinale) {
      next();
      return;
    }
    _pendingFinale = false;
    unawaited(_services.save.markFinaleSeen());
    _game.overlays.remove(WinModal.overlayId);
    // The hunt is over, so its bar goes too: left up, it sat across the
    // bottom of the ending asking the player to find Findo.
    _game.overlays.remove(HudOverlay.overlayId);
    _game.overlays.add(FinaleScreen.overlayId);
  }

  void _closeRank() {
    final next = _rankThen;
    _rankThen = null;
    setState(() => _pendingRank = null);
    _game.overlays.remove(RankScreen.overlayId);
    next?.call();
  }

  void _restart(LevelDefinition level) {
    setState(() {
      _game.overlays.clear();
      _startLevel(level);
    });
  }

  void _backToLevelList() {
    _services.levels.clearCurrent();
    Navigator.of(context).pop();
  }

  // -- pause and hints -----------------------------------------------------

  void _pause() {
    _services.audio.play(GameSound.tap);
    _game.setAccepting(false);
    _game.overlays.add(PauseModal.overlayId);
    // A paused game kept drawing: the drift went on falling behind the panel
    // and the whole scene was redrawn sixty times a second for a player who
    // had put the phone down. Stopping the loop leaves the last frame on
    // screen, which is all the panel needs behind it.
    _game.pauseEngine();
  }

  /// Opens Findo full size. The clock stops while she is up: otherwise the
  /// panel is free thinking time, and taps aimed at it fall through to the map.
  void _openCharacterSheet() {
    if (_game.overlays.isActive(CharacterSheetModal.overlayId)) {
      return;
    }
    _services.audio.play(GameSound.peek);
    _game.setAccepting(false);
    _game.overlays.add(CharacterSheetModal.overlayId);
  }

  void _closeCharacterSheet() {
    _game.overlays.remove(CharacterSheetModal.overlayId);
    _game.setAccepting(true);
  }

  void _resume() {
    _services.audio.play(GameSound.tap);
    _game.overlays.remove(PauseModal.overlayId);
    _game.resumeEngine();
    _game.setAccepting(true);
  }

  Future<void> _requestHint() async {
    if (_services.levels.isFound || widget.daily != null) {
      return;
    }
    // The guided hunt's hint is on the house: it is there to show what a
    // hint does, not to spend one of the three the player starts with.
    final tutorial = _tutorial;
    if (tutorial != null && tutorial.step == TutorialStep.hint) {
      _game.revealHint();
      tutorial.did(TutorialStep.hint);
      return;
    }
    _services.audio.play(GameSound.tap);
    _game.setAccepting(false);
    final choice = await showHintDialog(context, _services.monetization);
    if (!mounted) {
      return;
    }
    var granted = false;
    switch (choice) {
      case HintChoice.useStored:
        granted = await _services.monetization.consumeHint();
      case HintChoice.watchAd:
        granted = await _services.monetization.showRewardedForHint();
        if (granted) {
          // The reward is banked as a hint, so spend it straight away.
          granted = await _services.monetization.consumeHint();
        }
      case HintChoice.cancel:
        granted = false;
    }
    if (!mounted) {
      return;
    }
    _game.setAccepting(true);
    if (granted) {
      _game.revealHint();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (_game.overlays.isActive(CharacterSheetModal.overlayId)) {
          _closeCharacterSheet();
        } else if (_game.overlays.isActive(PauseModal.overlayId)) {
          _resume();
        } else if (_game.overlays.isActive(WinModal.overlayId) ||
            _game.overlays.isActive(TimeUpModal.overlayId) ||
            _game.overlays.isActive(DailyResultPanel.overlayId)) {
          _leaveLevel(_backToLevelList);
        } else {
          _pause();
        }
      },
      child: Scaffold(
        body: GameWidget<FindoGame>(
          game: _game,
          loadingBuilder: (context) => Center(
            child: Text(
              context.l10n.t('common.loading'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          initialActiveOverlays: [
            HudOverlay.overlayId,
            if (_tutorial?.active ?? false) TutorialOverlay.overlayId,
          ],
          overlayBuilderMap: {
            HudOverlay.overlayId: (context, game) => HudOverlay(
                  game: game,
                  monetization: _services.monetization,
                  onPause: _pause,
                  onHint: _requestHint,
                  onOpenCharacter: _openCharacterSheet,
                  daily: widget.daily != null,
                ),
            TutorialOverlay.overlayId: (context, game) {
              final tutorial = _tutorial;
              if (tutorial == null) {
                return const SizedBox.shrink();
              }
              return TutorialOverlay(game: game, controller: tutorial);
            },
            TipBanner.overlayId: (context, game) {
              final key = _tipKey;
              if (key == null) {
                return const SizedBox.shrink();
              }
              return TipBanner(key: ValueKey(key), tipKey: key, onDone: _hideTip);
            },
            DailyResultPanel.overlayId: (context, game) {
              final outcome = _dailyOutcome;
              if (outcome == null) {
                return const SizedBox.shrink();
              }
              return DailyResultPanel(
                outcome: outcome,
                onShare: () => _shareDaily(outcome),
                onTable: _showDailyTable,
                onHome: () => _leaveLevel(_backToLevelList),
              );
            },
            CharacterSheetModal.overlayId: (context, game) =>
                CharacterSheetModal(onClose: _closeCharacterSheet),
            PauseModal.overlayId: (context, game) => PauseModal(
                  onResume: _resume,
                  onQuit: () => _leaveLevel(_backToLevelList),
                ),
            WinModal.overlayId: (context, game) {
              final result = _result;
              if (result == null) {
                return const SizedBox.shrink();
              }
              final next = _services.levels.levelAfter(game.level);
              return WinModal(
                result: result,
                totalStars: _totalStars,
                starHints: _starHints,
                hasNextLevel: next != null,
                moreComing: next == null && game.level.index < _finaleLevel,
                onShare: () => _shareLevel(result),
                onNext: () => _afterRank(() => _leaveLevel(() => _restart(next!))),
                onReplay: () =>
                    _afterRank(() => _leaveLevel(() => _restart(game.level))),
                onLevelList: () => _afterRank(() => _leaveLevel(_backToLevelList)),
              );
            },
            // The ending describes the whole game, not the level that set it
            // off: a hundred levels, the last rank, and three stars for each
            // level. Derived from the level just cleared, a demo run showed
            // "10 levels" and the first rank.
            FinaleScreen.overlayId: (context, game) => FinaleScreen(
                  stars: _services.save.totalStars,
                  starsPossible: _finaleLevel * 3,
                  rank: const Rank(Rank.count),
                  mapAsset: game.level.map,
                  chaseLevel: _services.levels.closestToThreeStars(),
                  onChase: (level) => _restart(level),
                  onLevelList: _backToLevelList,
                ),
            RankScreen.overlayId: (context, game) {
              final rank = _pendingRank;
              if (rank == null) {
                return const SizedBox.shrink();
              }
              return RankScreen(rank: rank, onDone: _closeRank);
            },
            TimeUpModal.overlayId: (context, game) => TimeUpModal(
                  onRetry: () => _leaveLevel(() => _restart(game.level)),
                  onLevelList: () => _leaveLevel(_backToLevelList),
                ),
          },
        ),
      ),
    );
  }
}
