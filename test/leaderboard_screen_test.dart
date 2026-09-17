import 'package:findo/managers/localization_manager.dart';
import 'package:findo/managers/save_manager.dart';
import 'package:findo/models/leaderboard.dart';
import 'package:findo/ui/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Daily Hunt's table inside the game. Play Games cannot run in a test,
/// so the screen is handed a fake source and checked for what it shows in
/// each state: a table, the player's own place, sign-in, failure and empty.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalizationManager localization;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // No dictionary loaded: every string renders as its key, which is what
    // the expectations below look for.
    localization = LocalizationManager(await SaveManager.load());
  });

  Future<void> pump(
    WidgetTester tester, {
    required Future<LeaderboardLoad> Function(LeaderboardSpan) load,
    Future<bool> Function()? signIn,
  }) async {
    await tester.pumpWidget(
      LocalizationScope(
        manager: localization,
        child: MaterialApp(
          home: LeaderboardScreen(load: load, signIn: signIn ?? () async => true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const table = LeaderboardLoad.ok(
    top: [
      LeaderboardRow(rank: 1, name: 'Noa', milliseconds: 18400),
      LeaderboardRow(rank: 2, name: 'Itai', milliseconds: 21050),
      LeaderboardRow(rank: 3, name: 'Maya', milliseconds: 23900),
    ],
    aroundMe: [
      LeaderboardRow(rank: 41, name: 'Dana', milliseconds: 39000),
      LeaderboardRow(rank: 42, name: 'Yoav', milliseconds: 39200, isMe: true),
    ],
  );

  testWidgets('shows the best times, then the player among their neighbours', (tester) async {
    await pump(tester, load: (span) async => table);

    expect(find.text('Noa'), findsOneWidget);
    expect(find.text('0:18.4'), findsOneWidget);
    expect(find.text('0:23.9'), findsOneWidget);
    expect(find.text('· · ·'), findsOneWidget, reason: 'no break between the top and the player');
    expect(find.text('Yoav · lb.you'), findsOneWidget, reason: 'the player is not marked');
    expect(find.text('0:39.2'), findsOneWidget);
  });

  testWidgets('each tab asks for its own period', (tester) async {
    final asked = <LeaderboardSpan>[];
    await pump(tester, load: (span) async {
      asked.add(span);
      return table;
    });
    expect(asked, [LeaderboardSpan.today]);

    await tester.tap(find.text('lb.tab.week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lb.tab.all'));
    await tester.pumpAndSettle();
    expect(asked, containsAll([LeaderboardSpan.week, LeaderboardSpan.allTime]));
  });

  testWidgets('a signed-out player can sign in and then sees the table', (tester) async {
    var signedIn = false;
    await pump(
      tester,
      load: (span) async => signedIn ? table : const LeaderboardLoad.signedOut(),
      signIn: () async => signedIn = true,
    );
    expect(find.text('lb.signedOut'), findsOneWidget);

    await tester.tap(find.text('lb.signIn'));
    await tester.pumpAndSettle();
    expect(find.text('Noa'), findsOneWidget);
  });

  testWidgets('a failed load offers to try again', (tester) async {
    var attempts = 0;
    await pump(tester, load: (span) async {
      attempts++;
      return attempts == 1 ? const LeaderboardLoad.failed() : table;
    });
    expect(find.text('lb.error'), findsOneWidget);

    await tester.tap(find.text('lb.retry'));
    await tester.pumpAndSettle();
    expect(find.text('Noa'), findsOneWidget);
  });

  testWidgets('an empty period says so', (tester) async {
    await pump(tester, load: (span) async => const LeaderboardLoad.ok(top: []));
    expect(find.text('lb.empty'), findsOneWidget);
  });
}
