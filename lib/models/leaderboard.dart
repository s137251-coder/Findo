/// The periods a Play Games leaderboard keeps: it turns over daily and weekly,
/// and keeps an all-time table besides.
enum LeaderboardSpan { today, week, allTime }

/// One line of a leaderboard as the game shows it.
class LeaderboardRow {
  const LeaderboardRow({
    required this.rank,
    required this.name,
    required this.milliseconds,
    this.isMe = false,
  });

  final int rank;
  final String name;
  final int milliseconds;

  /// The player looking at the table.
  final bool isMe;
}

/// What loading a leaderboard came back with.
enum LeaderboardStatus { ok, signedOut, failed, unsupported }

class LeaderboardLoad {
  const LeaderboardLoad._(this.status, this.top, this.aroundMe);

  const LeaderboardLoad.ok({
    required List<LeaderboardRow> top,
    List<LeaderboardRow> aroundMe = const [],
  }) : this._(LeaderboardStatus.ok, top, aroundMe);

  const LeaderboardLoad.signedOut() : this._(LeaderboardStatus.signedOut, const [], const []);
  const LeaderboardLoad.failed() : this._(LeaderboardStatus.failed, const [], const []);
  const LeaderboardLoad.unsupported() : this._(LeaderboardStatus.unsupported, const [], const []);

  final LeaderboardStatus status;

  /// The best times, in rank order.
  final List<LeaderboardRow> top;

  /// The player and a few around them, when they are ranked below [top].
  final List<LeaderboardRow> aroundMe;
}
