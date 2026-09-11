import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'save_manager.dart';

/// Every sound the game can play, mapped to a file in `assets/audio/`.
enum GameSound {
  found('found.wav'),
  misclick('misclick.wav'),
  combo('combo.wav'),
  hint('hint.wav'),
  win('win.wav'),
  star('star.wav'),
  peek('peek.wav'),
  swoosh('swoosh.wav'),
  tap('click.wav');

  const GameSound(this.fileName);

  final String fileName;
}

/// Owns background music and sound effects, and keeps them in step with the
/// player's settings and with the app lifecycle.
///
/// Playback failures are swallowed on purpose: a device that refuses audio
/// focus should cost the player a sound, never the level they are in.
class AudioManager with WidgetsBindingObserver {
  AudioManager(this._saveManager);

  static const _bgmFile = 'bgm_main.wav';

  /// Music themes, one per scene family. Twenty-five levels sharing a single
  /// loop is what wore the old soundtrack out; a farm and a night festival
  /// should not sound the same.
  static const _themes = <String>[
    'bright', 'rustic', 'breezy', 'busy', 'frost', 'dusk',
  ];

  /// Which theme each level uses, by `nameKey`. Anything missing falls back to
  /// [_bgmFile], so a new level never ships silent.
  static const _levelThemes = <String, String>{
    'level.town': 'bright',
    'level.farm': 'rustic',
    'level.fair': 'bright',
    'level.beach': 'breezy',
    'level.station': 'busy',
    'level.market': 'bright',
    'level.snow': 'frost',
    'level.museum': 'dusk',
    'level.stadium': 'busy',
    'level.airport': 'busy',
    'level.zoo': 'bright',
    'level.water': 'breezy',
    'level.mall': 'busy',
    'level.castle': 'rustic',
    'level.hospital': 'dusk',
    'level.site': 'busy',
    'level.marathon': 'busy',
    'level.festival': 'dusk',
    'level.nightfest': 'dusk',
    'level.docks': 'breezy',
    'level.rooftop': 'dusk',
    'level.glasshouse': 'breezy',
    'level.skibase': 'frost',
    'level.library': 'dusk',
    'level.farmers': 'rustic',
    'level.aquarium': 'breezy',
    'level.cathedral': 'dusk',
    'level.busdepot': 'busy',
    'level.waterpark': 'bright',
  };

  /// The track a level should play, as a file name.
  static String trackForLevel(String? nameKey) {
    final theme = _levelThemes[nameKey];
    return theme == null ? _bgmFile : 'bgm_$theme.wav';
  }

  String? _currentTrack;

  final SaveManager _saveManager;

  bool _initialized = false;
  bool _musicWasPlaying = false;

  bool get musicEnabled => _saveManager.musicEnabled;

  bool get sfxEnabled => _saveManager.sfxEnabled;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      await FlameAudio.audioCache.loadAll([
        _bgmFile,
        ..._themes.map((theme) => 'bgm_$theme.wav'),
        ...GameSound.values.map((sound) => sound.fileName),
      ]);
    } catch (error, stack) {
      _report('preload failed', error, stack);
    }
  }

  Future<void> setMusicEnabled(bool value) async {
    await _saveManager.setMusicEnabled(value);
    if (value) {
      await startMusic(track: _currentTrack);
    } else {
      await stopMusic();
    }
  }

  Future<void> setSfxEnabled(bool value) => _saveManager.setSfxEnabled(value);

  /// Starts the music, or switches to [track] if a different one is playing.
  ///
  /// Passing no track keeps whatever is already on, which is what the home
  /// screen wants; a level passes its own so the soundtrack follows the scene.
  Future<void> startMusic({String? track}) async {
    if (!musicEnabled) {
      return;
    }
    final wanted = track ?? _currentTrack ?? _bgmFile;
    try {
      if (FlameAudio.bgm.isPlaying) {
        if (wanted == _currentTrack) {
          return;
        }
        // Switching tracks means stopping first: the player holds one source.
        await FlameAudio.bgm.stop();
      }
      await FlameAudio.bgm.play(wanted, volume: 0.45);
      _currentTrack = wanted;
      _musicWasPlaying = true;
    } catch (error, stack) {
      _report('bgm start failed', error, stack);
    }
  }

  Future<void> stopMusic() async {
    try {
      await FlameAudio.bgm.stop();
    } catch (error, stack) {
      _report('bgm stop failed', error, stack);
    }
    _musicWasPlaying = false;
  }

  Future<void> play(GameSound sound, {double volume = 1.0}) async {
    if (!sfxEnabled) {
      return;
    }
    try {
      await FlameAudio.play(sound.fileName, volume: volume);
    } catch (error, stack) {
      _report('sfx ${sound.fileName} failed', error, stack);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _musicWasPlaying = FlameAudio.bgm.isPlaying;
        if (_musicWasPlaying) {
          FlameAudio.bgm.pause();
        }
      case AppLifecycleState.resumed:
        if (_musicWasPlaying && musicEnabled) {
          FlameAudio.bgm.resume();
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await stopMusic();
  }

  void _report(String message, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('AudioManager: $message ($error)');
    }
  }
}
