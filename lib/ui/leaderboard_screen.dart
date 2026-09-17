import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../managers/localization_manager.dart';
import '../models/leaderboard.dart';
import '../theme.dart';
import 'daily_hunt_ui.dart';
import 'motion.dart';
import 'safe_area_wrapper.dart';

/// Opens the Daily Hunt's table in the game's own screen.
Future<void> openLeaderboard(
  BuildContext context, {
  LeaderboardSpan initial = LeaderboardSpan.today,
}) {
  final games = AppServices.of(context).games;
  return Navigator.of(context).push(
    findoRoute<void>(
      LeaderboardScreen(
        load: games.loadTable,
        signIn: games.signIn,
        openInGoogle: games.showTable,
        initial: initial,
      ),
    ),
  );
}

/// The Daily Hunt's leaderboard: today, this week and all time.
///
/// Read from Google Play Games and drawn in the game's own colours, rather
/// than handing the player over to Play Games' screen -- which stays one tap
/// away at the bottom for anyone who wants it.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({
    super.key,
    required this.load,
    required this.signIn,
    this.openInGoogle,
    this.initial = LeaderboardSpan.today,
  });

  final Future<LeaderboardLoad> Function(LeaderboardSpan span) load;
  final Future<bool> Function() signIn;
  final Future<bool> Function(LeaderboardSpan span)? openInGoogle;
  final LeaderboardSpan initial;

  static const _spans = [
    LeaderboardSpan.today,
    LeaderboardSpan.week,
    LeaderboardSpan.allTime,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: _spans.length,
      initialIndex: _spans.indexOf(initial),
      child: Scaffold(
        backgroundColor: FindoColors.background,
        body: SafeAreaWrapper(
          maxContentWidth: 560,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const BackButtonIcon(),
                    tooltip: l10n.t('common.back'),
                    color: FindoColors.textPrimary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('lb.title'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.t('daily.title'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: FindoColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.leaderboard_rounded,
                    color: FindoColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: FindoColors.surface,
                  borderRadius: BorderRadius.circular(
                    FindoMetrics.radiusControl,
                  ),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: FindoColors.primary,
                    borderRadius: BorderRadius.circular(
                      FindoMetrics.radiusControl,
                    ),
                  ),
                  labelColor: FindoColors.onPrimary,
                  unselectedLabelColor: FindoColors.textMuted,
                  labelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    Tab(text: l10n.t('lb.tab.today')),
                    Tab(text: l10n.t('lb.tab.week')),
                    Tab(text: l10n.t('lb.tab.all')),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final span in _spans)
                      _Table(
                        span: span,
                        load: load,
                        signIn: signIn,
                        openInGoogle: openInGoogle,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One period's table: loads when first shown, and again on a pull.
class _Table extends StatefulWidget {
  const _Table({
    required this.span,
    required this.load,
    required this.signIn,
    required this.openInGoogle,
  });

  final LeaderboardSpan span;
  final Future<LeaderboardLoad> Function(LeaderboardSpan span) load;
  final Future<bool> Function() signIn;
  final Future<bool> Function(LeaderboardSpan span)? openInGoogle;

  @override
  State<_Table> createState() => _TableState();
}

class _TableState extends State<_Table> with AutomaticKeepAliveClientMixin {
  LeaderboardLoad? _result;

  /// Counts loads, so a slow answer that arrives after a newer request was
  /// made cannot overwrite the newer one.
  int _generation = 0;

  // Switching tabs back and forth keeps what was loaded instead of asking
  // Play Games again each time.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() => _result = null);
    final result = await widget.load(widget.span);
    if (mounted && generation == _generation) {
      setState(() => _result = result);
    }
  }

  Future<void> _signIn() async {
    await widget.signIn();
    if (mounted) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final result = _result;
    if (result == null) {
      return const Center(
        child: CircularProgressIndicator(color: FindoColors.primary),
      );
    }
    switch (result.status) {
      case LeaderboardStatus.unsupported:
        return _Message(text: l10n.t('lb.unsupported'));
      case LeaderboardStatus.signedOut:
        return _Message(
          text: l10n.t('lb.signedOut'),
          action: l10n.t('lb.signIn'),
          onAction: _signIn,
        );
      case LeaderboardStatus.failed:
        return _Message(
          text: l10n.t('lb.error'),
          action: l10n.t('lb.retry'),
          onAction: _reload,
        );
      case LeaderboardStatus.ok:
        break;
    }

    final children = <Widget>[];
    if (result.top.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Text(
            l10n.t('lb.empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: FindoColors.textMuted),
          ),
        ),
      );
    } else {
      for (final row in result.top) {
        children.add(_Row(row: row));
      }
      if (result.aroundMe.isNotEmpty) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Text(
                '· · ·',
                style: TextStyle(fontSize: 20, color: FindoColors.textMuted),
              ),
            ),
          ),
        );
        for (final row in result.aroundMe) {
          children.add(_Row(row: row));
        }
      }
    }
    if (widget.openInGoogle != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: TextButton(
            onPressed: () => widget.openInGoogle!(widget.span),
            child: Text(
              l10n.t('lb.openInGoogle'),
              style: const TextStyle(color: FindoColors.textMuted),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: FindoColors.primary,
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        children: children,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final LeaderboardRow row;

  static const _medals = {
    1: Color(0xFFFFC53D),
    2: Color(0xFFC9D1DE),
    3: Color(0xFFD9955B),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final medal = _medals[row.rank];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: row.isMe ? FindoColors.surfaceRaised : FindoColors.surface,
        borderRadius: BorderRadius.circular(FindoMetrics.radiusControl),
        border: Border.all(
          color: row.isMe ? FindoColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: medal != null
                ? Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: medal,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${row.rank}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: FindoColors.onPrimary,
                      ),
                    ),
                  )
                : Text(
                    '${row.rank}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: FindoColors.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          _Avatar(base64Image: row.avatarBase64, name: row.name),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.isMe ? '${row.name} · ${l10n.t('lb.you')}' : row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: row.isMe ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Times read left to right whatever the language.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              formatDailyTime(row.milliseconds),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: row.isMe ? FindoColors.primary : FindoColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.base64Image, required this.name});

  final String? base64Image;
  final String name;

  @override
  Widget build(BuildContext context) {
    final image = base64Image;
    if (image != null && image.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(image),
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => _initial(),
          ),
        );
      } catch (_) {
        // A picture that does not decode falls back to the initial.
      }
    }
    return _initial();
  }

  Widget _initial() {
    final letter = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: FindoColors.surfaceRaised,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.leaderboard_rounded,
              size: 44,
              color: FindoColors.textMuted,
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: FindoColors.textMuted,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
