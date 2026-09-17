import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:findo/managers/audio_manager.dart';
import 'package:findo/managers/save_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How many audio players a long session builds up.
///
/// `FlameAudio.play`, which this used to call, creates a new player for every
/// single sound and never disposes it: the native player stays registered and
/// its event channel stays open. A player who taps their way to level fifty
/// leaves hundreds behind, and the game slows down until it is closed and
/// opened again -- the exact complaint a tester made at level 57. The pool
/// this replaced it with has to stay a pool.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlayers players;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    players = _FakePlayers();
    AudioplayersPlatformInterface.instance = players;
    GlobalAudioplayersPlatformInterface.instance = _FakeGlobal();
  });

  testWidgets('hundreds of sounds are played on a handful of players',
      (tester) async {
    final audio = AudioManager(await SaveManager.load());

    await tester.runAsync(() async {
      for (var i = 0; i < 200; i++) {
        await audio.play(GameSound.tap);
        await audio.play(GameSound.misclick, volume: 0.8);
      }
    });

    expect(audio.voiceCount, AudioManager.sfxVoices);
    expect(players.created, AudioManager.sfxVoices,
        reason: '400 sounds should not be 400 players');
  });

  testWidgets('sound turned off asks for no player at all', (tester) async {
    final save = await SaveManager.load();
    await save.setSfxEnabled(false);
    final audio = AudioManager(save);

    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await audio.play(GameSound.tap);
      }
    });

    expect(audio.voiceCount, 0);
    expect(players.created, 0);
  });

  testWidgets('the voices are handed back when the game shuts down',
      (tester) async {
    final audio = AudioManager(await SaveManager.load());
    var voices = 0;
    await tester.runAsync(() async {
      await audio.play(GameSound.tap);
      await audio.play(GameSound.found);
      voices = audio.voiceCount;
      await audio.dispose();
    });
    expect(voices, greaterThan(0));
    // The music player is Flame's own and outlives any single voice, so only
    // the pool is counted here.
    expect(players.disposed, voices);
    expect(audio.voiceCount, 0);
  });
}

/// Stands in for the platform, and counts the players it is asked to make.
class _FakePlayers extends AudioplayersPlatformInterface {
  int created = 0;
  int disposed = 0;

  @override
  Future<void> create(String playerId) async => created++;

  @override
  Future<void> dispose(String playerId) async => disposed++;

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      const Stream<AudioEvent>.empty();

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<int?> getDuration(String playerId) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// The same for the one-off setup call every player waits on.
class _FakeGlobal implements GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() =>
      const Stream<GlobalAudioEvent>.empty();
}
