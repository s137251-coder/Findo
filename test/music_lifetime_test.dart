import 'dart:async';
import 'dart:io';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:findo/managers/audio_manager.dart';
import 'package:findo/managers/save_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who the music belongs to.
///
/// It is started for a hunt, and nothing used to stop it: the level's track
/// followed the player out to the level list and went on playing under the
/// title screen, which is meant to be quiet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AudioplayersPlatformInterface.instance = _SilentPlatform();
    GlobalAudioplayersPlatformInterface.instance = _SilentGlobal();
    // A track is played from a copy of the asset on disk, so the plugin that
    // says where to put that copy has to answer.
    final temporary = Directory.systemTemp.createTempSync('findo_music');
    addTearDown(() => temporary.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temporary.path,
    );
    // A player reports its position back on every frame, which a test would
    // still be waiting on after the tree is gone. Nothing here asks where the
    // music has got to.
    FlameAudio.bgm.audioPlayer.positionUpdater = null;
  });

  testWidgets('leaving the hunt leaves no track behind', (tester) async {
    final audio = AudioManager(await SaveManager.load());

    await tester.runAsync(() async {
      await audio.startRandomMusic();
      expect(audio.currentTrack, isNotNull, reason: 'the hunt had no music');

      await audio.endMusic();
    });

    expect(audio.currentTrack, isNull);
  });

  testWidgets('turning the music back on mid-hunt brings the track back',
      (tester) async {
    final save = await SaveManager.load();
    final audio = AudioManager(save);

    await tester.runAsync(() async {
      await audio.startRandomMusic();
      final track = audio.currentTrack;

      await audio.setMusicEnabled(false);
      await audio.setMusicEnabled(true);

      expect(audio.currentTrack, track, reason: 'the hunt lost its music');
    });
  });

  testWidgets('turning it on in the menu starts nothing', (tester) async {
    final audio = AudioManager(await SaveManager.load());

    await tester.runAsync(() async {
      await audio.startRandomMusic();
      // Out of the hunt and back at the menu.
      await audio.endMusic();

      await audio.setMusicEnabled(false);
      await audio.setMusicEnabled(true);
    });

    expect(audio.currentTrack, isNull);
  });
}

/// A platform that accepts everything and makes no sound.
class _SilentPlatform extends AudioplayersPlatformInterface {
  /// One event stream per player. A real player reports back that its source
  /// is ready, and the caller waits for that, so this has to as well.
  final Map<String, StreamController<AudioEvent>> _events = {};

  StreamController<AudioEvent> _channel(String playerId) => _events.putIfAbsent(
        playerId,
        () => StreamController<AudioEvent>.broadcast(),
      );

  @override
  Future<void> create(String playerId) async => _channel(playerId);

  @override
  Future<void> dispose(String playerId) async {
    await _events.remove(playerId)?.close();
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) => _channel(playerId).stream;

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    _channel(playerId).add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<int?> getDuration(String playerId) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _SilentGlobal implements GlobalAudioplayersPlatformInterface {
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
