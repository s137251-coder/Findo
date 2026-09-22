import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_services.dart';
import 'managers/audio_manager.dart';
import 'managers/leaderboard_service.dart';
import 'managers/level_manager.dart';
import 'managers/localization_manager.dart';
import 'managers/monetization_manager.dart';
import 'managers/save_manager.dart';
import 'theme.dart';
import 'firebase_options.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter will hold a hundred megabytes of decoded pictures by default. This
  // game shows a title screen, a list of thumbnails and one map at a time, so
  // that ceiling is not a budget -- it is just how much a phone can end up
  // holding before anything is given back, and on a cheap handset the rest of
  // the game pays for it. Forty is more than the screens ever need at once.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 << 20;

  await Flame.device.fullScreen();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final save = await SaveManager.load();
  final localization = LocalizationManager(save);
  await localization.initialize(
    WidgetsBinding.instance.platformDispatcher.locale,
  );

  final levels = LevelManager(save);
  await levels.loadCatalogue();

  final audio = AudioManager(save);
  await audio.initialize();

  // The leaderboard's home. A failure here costs the table and nothing else:
  // the game is played from the phone, and every call into it is allowed to
  // come back empty.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Who is allowed to write to the table.
    //
    // A leaderboard reached over the internet is a leaderboard anyone can
    // write to with a script, and a table full of impossible times is worth
    // nothing to the people who earned their place on it. App Check has the
    // phone prove to Google that the request came from this app, unmodified,
    // on a real device -- Play Integrity on Android, App Attest on an iPhone
    // -- before Firestore will accept a word of it.
    //
    // A debug build cannot prove any of that, so it says so and is given a
    // token that only works for devices registered by hand.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      // App Attest with DeviceCheck behind it: App Attest wants iOS 14, and
      // the older phones fall back rather than being shut out of the table.
      providerApple: kReleaseMode
          ? const AppleAppAttestWithDeviceCheckFallbackProvider()
          : const AppleDebugProvider(),
    );
  } catch (error) {
    debugPrint('leaderboard unavailable: $error');
  }

  final services = AppServices(
    save: save,
    localization: localization,
    audio: audio,
    levels: levels,
    monetization: MonetizationManager(save),
    table: LeaderboardService(save),
  );

  runApp(FindoApp(services: services));
}

/// The app shell. It rebuilds whenever the language changes, which is what
/// swaps both the strings and the layout direction.
class FindoApp extends StatefulWidget {
  const FindoApp({super.key, required this.services});

  final AppServices services;

  @override
  State<FindoApp> createState() => _FindoAppState();
}

class _FindoAppState extends State<FindoApp> {
  @override
  void initState() {
    super.initState();
    // Consent and the iOS tracking prompt need a live UI to attach to, so this
    // runs after the first frame rather than during startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.services.monetization.initialize();
    });
  }

  @override
  void dispose() {
    widget.services.audio.dispose();
    widget.services.monetization.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = widget.services.localization;
    return AppServicesScope(
      services: widget.services,
      child: LocalizationScope(
        manager: localization,
        child: ListenableBuilder(
          listenable: localization,
          builder: (context, _) {
            return MaterialApp(
              title: 'Findo',
              debugShowCheckedModeBanner: false,
              theme: buildFindoTheme(),
              locale: localization.locale,
              supportedLocales: LocalizationManager.supportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                return Directionality(
                  textDirection: localization.textDirection,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: const HomeScreen(),
            );
          },
        ),
      ),
    );
  }
}
