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
        ...GameSound.values.map((sound) => sound.fileName),
      ]);
    } catch (error, stack) {
      _report('preload failed', error, stack);
    }
  }

  Future<void> setMusicEnabled(bool value) async {
    await _saveManager.setMusicEnabled(value);
    if (value) {
      await startMusic();
    } else {
      await stopMusic();
    }
  }

  Future<void> setSfxEnabled(bool value) => _saveManager.setSfxEnabled(value);

  Future<void> startMusic() async {
    if (!musicEnabled) {
      return;
    }
    try {
      if (FlameAudio.bgm.isPlaying) {
        return;
      }
      await FlameAudio.bgm.play(_bgmFile, volume: 0.45);
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
