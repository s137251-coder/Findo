# Findo

A 2D hidden-object game in the "Where's Waldo" tradition. Each level is one
large illustrated scene packed with people, and one girl -- Findo -- hidden
somewhere in it. Find her before the clock runs out. Built with Flutter and the
Flame engine, for Android and iOS from one codebase.

Findo ships in **English and Hebrew**, with full right-to-left layout on the
Hebrew side, switchable from Settings without restarting.

---

## Running it

```powershell
flutter pub get
flutter run
```

Other useful commands:

```powershell
flutter analyze                      # static analysis, expected clean
flutter test                         # unit tests
flutter build apk --release          # installable APK for testing
flutter build appbundle --release    # the artifact Google Play accepts
flutter build ios --release          # requires macOS and Xcode
```

---

## How it plays

- **Drag** to move around the scene, **pinch** to zoom in. The camera is clamped
  so the map always fills the screen, and stops above the objective panel so
  nothing can hide underneath it.
- **Find Findo** -- brown braids, yellow top, purple skirt -- and tap her: +100
  points. She is drawn from the same routine as the crowd around her, so she
  genuinely blends in.
- **Tap the wrong person** and it costs 15 points and 3 seconds.
- **Leftover time** converts to bonus points at 10 per second, and the total
  decides 1 to 3 stars.
- **Hints** pan the camera towards Findo and make her glow. They are spent from
  a stored balance, earned by watching a rewarded video, or bought.

Tapping her is tested against the character's own alpha channel rather than her
bounding box, with a finger's worth of tolerance, so a tap in the gap between
her arm and her skirt is a miss -- as it should be.

---

## Layout

```
lib/
  main.dart                     app entry: managers, theme, localization, first frame
  app_services.dart             the manager bundle, reachable via AppServices.of(context)
  theme.dart                    colours, radii, ThemeData
  models/
    level_definition.dart       level, target and result models, and their JSON parsing
  managers/
    save_manager.dart           the only code that touches SharedPreferences
    localization_manager.dart   JSON dictionaries, RTL/LTR, persisted language
    level_manager.dart          level catalogue, whether Findo is found, unlocks
    score_manager.dart          scoring, countdown, time bonus, stars
    audio_manager.dart          BGM and SFX, settings-aware, lifecycle-aware
    monetization_manager.dart   ATT, UMP consent, AdMob, in-app purchases
  game/
    findo_game.dart             the FlameGame: camera, gestures, rules
    components/
      map_background_component.dart   the map, and the source of misclicks
      item_target_component.dart      Findo: alpha-precise tap, found burst, hint glow
  ui/
    home_screen.dart            title screen
    level_select_screen.dart    level grid with stars and best scores
    game_screen.dart            hosts the Flame canvas and all overlays
    hud_overlay.dart            score, timer, the objective panel, hint button
    win_modal.dart              level-complete summary, and the time-up panel
    pause_modal.dart            pause
    settings_dialog.dart        audio, language, store, privacy options
    hint_dialog.dart            spend a hint or watch a video
    safe_area_wrapper.dart      notch, Dynamic Island and status-bar insets
    widgets/common.dart         stars, panels, chips, Findo's portrait
assets/
  images/maps/                  2048x2048 scenes
  images/maps/meta/             one JSON per level: where Findo is, scoring, time
  images/targets/findo.png      the character, used by the map and the HUD alike
  audio/                        music and sound effects
  locales/                      en.json and he.json
  fonts/                        the Findo font family
tool/
  draw_people.py                the figure routine every character is drawn with
  generate_maps.py              regenerates the character and the scenes
  generate_audio.py             regenerates music and sound effects
  generate_brand.py             launcher icons and Play store graphics
  level_data.py                 registers a map and records where Findo is in it
docs/
  RELEASE_GUIDE_GOOGLE_PLAY.md  step-by-step publishing guide
  privacy-policy.html           ready to host, English and Hebrew
store/
  LISTING.md                    paste-ready listing copy and questionnaire answers
  UPLOAD_CHECKLIST.md           what is done and what still needs you
```

### Why the managers are plain `ChangeNotifier`s

The game state is small and its owners are unambiguous, so the app uses
`ChangeNotifier` with `ListenableBuilder` and two `InheritedWidget`s rather
than a state-management package. Adding one later is a local change: the
managers themselves have no Flutter dependencies beyond `ChangeNotifier`.

---

## Adding a level

Levels are data. Drop a map into `assets/images/maps/`, then tell the game
where Findo is hiding in it:

```powershell
python tool/level_data.py register --map assets/images/maps/level_04.png `
    --id level_04 --index 4 --name-key level.harbour `
    --target 1180 640 96 176 --time 120
```

`--target` is Findo's box in map pixels: x, y, width, height. The tool writes
`assets/images/maps/meta/level_04.json`, adds the level to the index, and warns
if the map is smaller than 2048px square or if the box falls outside it.

Then add `level.harbour` to both `assets/locales/en.json` and
`assets/locales/he.json`. `flutter test` checks that every registered level has
a map that exists, a target inside it, and a name in both languages.

To re-check everything at once:

```powershell
python tool/level_data.py verify
```

No Dart changes are needed for any of this.

---

## About the shipped art and audio

Every image and sound in `assets/` is generated:

```powershell
python tool/generate_maps.py     # Findo, and the three crowded scenes
python tool/generate_audio.py    # music and sound effects
python tool/generate_brand.py    # launcher icons and store graphics
```

The scenes are programmer art. They are honest about the mechanic -- the crowd
is drawn with the same routine as Findo herself, so the hunt is real -- but they
are meant to be replaced by an illustrator. **That swap is a first-class path,
not an afterthought:** drop a hand-drawn scene into `assets/images/maps/`,
register it with `tool/level_data.py`, and the game uses it. Nothing in the Dart
code refers to a particular map.

Maps are authored at 2048x2048 because the camera magnifies up to 3.2x the
fit-to-screen zoom, and both the map and the character render with
`FilterQuality.high`.

The background music is a WAV rather than an MP3. Both play identically through
`audioplayers`; WAV was chosen because it can be generated without an encoder in
the toolchain. Swapping in an MP3 means changing one constant in
`audio_manager.dart`.

The `Findo` font family is Roboto (Apache-2.0), bundled so typography is
identical on Android and iOS.

---

## Monetization and privacy

The repo is wired for AdMob and in-app purchases but ships **Google's official
test ad unit ids**, which is the only correct setting for an unpublished app.
`docs/RELEASE_GUIDE_GOOGLE_PLAY.md` lists exactly which constants to replace.

On first launch the app requests App Tracking Transparency on iOS, then runs
the Google UMP consent flow, and only then initializes the ad SDK. Settings has
a permanent "Privacy options" entry, which the consent framework requires.

All player data -- progress, stars, language, audio settings, purchases --
lives in `shared_preferences` on the device. The game sends nothing to a server
of its own.
