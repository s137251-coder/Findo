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
import 'win_modal.dart';

/// Hosts the Flame canvas and every Flutter overlay drawn on top of it.
///
/// The Flame side never navigates: it reports "cleared" or "time up", and this
/// widget decides which overlay to raise and what to persist.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level, this.daily});

  final LevelDefinition level;

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
    _startLevel(widget.level);
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
    );
    _hasGame = true;
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
    _scoreManager.dispose();
    super.dispose();
  }

  // -- outcomes ------------------------------------------------------------

  Future<void> _handleLevelCleared() async {
    if (widget.daily != null) {
      return _handleDailyEnd(found: true);
    }
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
    setState(() {
      _result = result;
      _pendingRank = pending;
      _totalStars = _services.save.totalStars;
      _starHints = starHints;
    });
    _game.setAccepting(false);
    _game.overlays.add(WinModal.overlayId);
  }

  Future<void> _handleTimeUp() async {
    if (widget.daily != null) {
      return _handleDailyEnd(found: false);
    }
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
    if (!official) {
      return;
    }
    await _services.save.recordDailyTime(found ? milliseconds : -1);
    if (!found) {
      return;
    }
    final posted = await _services.games.submitDailyTime(milliseconds);
    final rank = posted ? await _services.games.todaysRank() : null;
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
  Future<void> _leaveLevel(VoidCallback next) async {
    await _services.monetization.onLevelFinished();
    if (!mounted) {
      return;
    }
    next();
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
    _game.setAccepting(true);
  }

  Future<void> _requestHint() async {
    if (_services.levels.isFound || widget.daily != null) {
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
          initialActiveOverlays: const [HudOverlay.overlayId],
          overlayBuilderMap: {
            HudOverlay.overlayId: (context, game) => HudOverlay(
                  game: game,
                  monetization: _services.monetization,
                  onPause: _pause,
                  onHint: _requestHint,
                  onOpenCharacter: _openCharacterSheet,
                  daily: widget.daily != null,
                ),
            DailyResultPanel.overlayId: (context, game) {
              final outcome = _dailyOutcome;
              if (outcome == null) {
                return const SizedBox.shrink();
              }
              return DailyResultPanel(
                outcome: outcome,
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
