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
  static const _promoteFile = 'promote.wav';

  /// Folders under `assets/audio/` holding the real recordings. Whatever is
  /// in them is used; dropping another file in needs no code change, because
  /// the pools are read from the asset manifest at startup rather than listed
  /// here.
  static const _okFolder = 'ok/';
  static const _notOkFolder = 'notok/';
  static const _musicFolder = 'music/';
  static const _promoteFolder = 'promote/';

  /// Everything found in those folders, as paths relative to the audio cache
  /// prefix. Empty until [initialize] has run, and empty for good on a build
  /// where a folder ships no files -- every caller falls back to the
  /// synthesised sound in that case, so the game is never silent.
  final List<String> _okPool = [];
  final List<String> _notOkPool = [];
  final List<String> _musicPool = [];
  final List<String> _promotePool = [];

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
        _promoteFile,
        ...GameSound.values.map((sound) => sound.fileName),
        // Music is deliberately not preloaded: the tracks are long, and the
        // one a level needs is fetched when that level starts.
        ..._okPool,
        ..._notOkPool,
        ..._promotePool,
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
        } else if (relative.startsWith(_promoteFolder)) {
          _promotePool.add(relative);
        }
      }
      // Sorted so a given build always enumerates them the same way; the
      // choice itself is random, the listing order is not.
      _okPool.sort();
      _notOkPool.sort();
      _musicPool.sort();
      _promotePool.sort();
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

  /// How many sound effects can overlap. Four covers the busiest moment in the
  /// game -- a found sting over a star chime over the tap that set them off --
  /// and a fifth sound simply takes the oldest voice back.
  static const sfxVoices = 4;

  /// The voices, created once and reused for the life of the app.
  final List<AudioPlayer> _sfxPlayers = [];
  int _nextVoice = 0;

  /// How many players exist. Never more than [sfxVoices], however long the
  /// session runs.
  @visibleForTesting
  int get voiceCount => _sfxPlayers.length;

  /// A voice to play the next effect on.
  ///
  /// This exists because `FlameAudio.play` builds a brand new player for every
  /// single sound and never disposes it: the native player stays registered,
  /// its event channel stays open, and nothing ever takes them back. One tap
  /// is nothing; a player who taps their way to level fifty has left hundreds
  /// of them behind, and the whole game slows down until the app is closed and
  /// opened again -- which is exactly what testers reported. A fixed few
  /// players, reused, cost the same at level one and at level a hundred.
  /// Sound effects mix with whatever else is playing, the music included.
  ///
  /// Without this a voice asks Android for audio focus the moment it plays,
  /// and the system stops the music to give it -- so tapping Findo's portrait
  /// killed the soundtrack, and nothing brought it back. Flame sets exactly
  /// this on every sound it plays; the pool has to as well.
  static final AudioContext _mixWithMusic = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  Future<AudioPlayer> _voice() async {
    if (_sfxPlayers.length < sfxVoices) {
      final player = AudioPlayer()..audioCache = FlameAudio.audioCache;
      // Added before the first await, so two sounds firing at once cannot both
      // decide the ring still has room.
      _sfxPlayers.add(player);
      await player.setAudioContext(_mixWithMusic);
      // Stop rather than release: a released player throws its source away and
      // has to prepare it again next time, which is the latency this pool is
      // meant to avoid.
      await player.setReleaseMode(ReleaseMode.stop);
      return player;
    }
    final player = _sfxPlayers[_nextVoice];
    _nextVoice = (_nextVoice + 1) % _sfxPlayers.length;
    return player;
  }

  Future<void> _playClip(String clip, {double volume = 1.0}) async {
    if (!sfxEnabled) {
      return;
    }
    try {
      final player = await _voice();
      await player.play(
        AssetSource(clip),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
    } catch (error, stack) {
      _report('sfx $clip failed', error, stack);
    }
  }

  /// Plays the promotion fanfare: a recording from `assets/audio/promote` if
  /// one shipped, else the synthesised one.
  Future<void> playPromotion() async {
    final clip = _pick(_promotePool);
    if (clip == null) {
      return _playClip(_promoteFile);
    }
    await _playClip(clip);
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
    if (!value) {
      return stopMusic();
    }
    // Only back to a hunt that is still going. Turning music on from the menu,
    // where nothing was playing, should not start a soundtrack over a screen
    // that has none.
    if (_currentTrack != null) {
      await startMusic(track: _currentTrack);
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

  /// Stops the music but remembers the track, so turning the sound back on
  /// mid-hunt picks it up again.
  Future<void> stopMusic() async {
    try {
      await FlameAudio.bgm.stop();
    } catch (error, stack) {
      _report('bgm stop failed', error, stack);
    }
    _musicWasPlaying = false;
  }

  /// Ends the hunt's music for good: it stops, and there is nothing to go back
  /// to.
  ///
  /// A track belongs to the hunt it was started for. Nothing used to stop it,
  /// so the level's music followed the player out to the level list and on to
  /// the title screen, where it played under a screen that is meant to be
  /// quiet -- and the next level then started a second track over it.
  Future<void> endMusic() async {
    await stopMusic();
    _currentTrack = null;
  }

  /// The track playing, or null when no hunt owns the music.
  @visibleForTesting
  String? get currentTrack => _currentTrack;

  Future<void> play(GameSound sound, {double volume = 1.0}) =>
      _playClip(sound.fileName, volume: volume);

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
    for (final player in _sfxPlayers) {
      try {
        await player.dispose();
      } catch (error, stack) {
        _report('voice not released', error, stack);
      }
    }
    _sfxPlayers.clear();
  }

  void _report(String message, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('AudioManager: $message ($error)');
    }
  }
}
