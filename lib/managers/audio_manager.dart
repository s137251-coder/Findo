import 'dart:math';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
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

  /// Folders under `assets/audio/` holding the real recordings. Whatever is
  /// in them is used; dropping another file in needs no code change, because
  /// the pools are read from the asset manifest at startup rather than listed
  /// here.
  static const _okFolder = 'ok/';
  static const _notOkFolder = 'notok/';
  static const _musicFolder = 'music/';

  /// Everything found in those folders, as paths relative to the audio cache
  /// prefix. Empty until [initialize] has run, and empty for good on a build
  /// where a folder ships no files -- every caller falls back to the
  /// synthesised sound in that case, so the game is never silent.
  final List<String> _okPool = [];
  final List<String> _notOkPool = [];
  final List<String> _musicPool = [];

  final Random _random = Random();

  /// The last track handed out, so a two-track pool still alternates instead
  /// of repeating the same one by chance.
  String? _lastMusic;

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
    await _discoverPools();
    try {
      await FlameAudio.audioCache.loadAll([
        _bgmFile,
        ...GameSound.values.map((sound) => sound.fileName),
        // Music is deliberately not preloaded: the tracks are long, and the
        // one a level needs is fetched when that level starts.
        ..._okPool,
        ..._notOkPool,
      ]);
    } catch (error, stack) {
      _report('preload failed', error, stack);
    }
  }

  /// Reads the asset manifest and sorts the audio folders into pools.
  Future<void> _discoverPools() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      const prefix = 'assets/audio/';
      for (final asset in manifest.listAssets()) {
        if (!asset.startsWith(prefix)) {
          continue;
        }
        final relative = asset.substring(prefix.length);
        if (relative.startsWith(_okFolder)) {
          _okPool.add(relative);
        } else if (relative.startsWith(_notOkFolder)) {
          _notOkPool.add(relative);
        } else if (relative.startsWith(_musicFolder)) {
          _musicPool.add(relative);
        }
      }
      // Sorted so a given build always enumerates them the same way; the
      // choice itself is random, the listing order is not.
      _okPool.sort();
      _notOkPool.sort();
      _musicPool.sort();
    } catch (error, stack) {
      _report('asset manifest unreadable', error, stack);
    }
  }

  /// A random entry, or null when the pool shipped empty.
  String? _pick(List<String> pool) =>
      pool.isEmpty ? null : pool[_random.nextInt(pool.length)];

  /// Plays the sound for finding her: one of the success recordings, or the
  /// synthesised sting when none shipped.
  Future<void> playFound() async {
    final clip = _pick(_okPool);
    if (clip == null) {
      return play(GameSound.found);
    }
    await _playClip(clip);
  }

  /// Plays the sound for tapping the wrong person.
  Future<void> playMisclick({double volume = 0.8}) async {
    final clip = _pick(_notOkPool);
    if (clip == null) {
      return play(GameSound.misclick, volume: volume);
    }
    await _playClip(clip, volume: volume);
  }

  Future<void> _playClip(String clip, {double volume = 1.0}) async {
    if (!sfxEnabled) {
      return;
    }
    try {
      await FlameAudio.play(clip, volume: volume);
    } catch (error, stack) {
      _report('sfx $clip failed', error, stack);
    }
  }

  /// Starts a random track from `assets/audio/music` and loops it.
  ///
  /// Used for the menu as well as for levels: the synthesised loop is the
  /// fallback for a build with no music shipped, not something to play at
  /// people who do have real music. Flame's background player runs in
  /// [ReleaseMode.loop], so a fifteen second piece covers a three minute hunt
  /// without any timer here.
  Future<void> startRandomMusic() async {
    if (_musicPool.isEmpty) {
      return startMusic(track: _bgmFile);
    }
    var chosen = _pick(_musicPool)!;
    if (_musicPool.length > 1 && chosen == _lastMusic) {
      // One retry is enough to stop an obvious immediate repeat without
      // making the sequence predictable.
      chosen = _pick(_musicPool)!;
    }
    _lastMusic = chosen;
    await startMusic(track: chosen);
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
