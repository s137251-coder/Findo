import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'save_manager.dart';

/// How a sign-in attempt ended, for the message Settings shows.
enum AccountOutcome { signedIn, cancelled, failed, unavailable }

/// Signing in with Google, so progress and purchases follow the player to a
/// new phone.
///
/// Every install already has an anonymous Firebase identity -- it is what the
/// Daily Hunt's table is written under. Signing in *links* Google to that
/// identity rather than replacing it, so the player keeps their place on the
/// table and nothing they have done is lost. Only when the Google account
/// already belongs to another identity (the player signed in on their old
/// phone first) does the game switch to that identity, and then the two saves
/// are merged, keeping the better of each.
///
/// The save itself is one Firestore document per player, `saves/{uid}`, that
/// only they can read or write. It is pushed a few seconds after anything in
/// it changes, and pulled when the player signs in and when the game opens.
///
/// Signing in is optional and the game never asks for it in the middle of
/// play: the only way in is the button in Settings.
class AccountService extends ChangeNotifier {
  AccountService(this._save, {List<Listenable> watch = const []}) {
    for (final source in watch) {
      source.addListener(schedulePush);
    }
  }

  final SaveManager _save;

  /// Called after a save from the account was folded into this phone's, so
  /// the screens showing progress and hints can catch up.
  VoidCallback? onMerged;

  /// Seconds of quiet before a change is pushed, so clearing a level -- which
  /// changes the progress, the stars and maybe the hints -- is one write.
  static const pushDelay = Duration(seconds: 3);

  Timer? _pending;

  /// What was last written, so a change that changes nothing -- an ad
  /// loading, a level starting -- does not cost a write.
  String? _lastPushed;
  StreamSubscription<User?>? _changes;
  bool _busy = false;
  DateTime? _lastSynced;

  bool get available => Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get _user => available ? _auth.currentUser : null;

  /// True when this install is tied to a Google account.
  bool get isSignedIn {
    final user = _user;
    return user != null &&
        !user.isAnonymous &&
        user.providerData.any((info) => info.providerId == 'google.com');
  }

  /// The address shown in Settings, so the player knows which account it is.
  String? get email {
    final user = _user;
    if (user == null) {
      return null;
    }
    for (final info in user.providerData) {
      if (info.providerId == 'google.com' && info.email != null) {
        return info.email;
      }
    }
    return user.email;
  }

  bool get busy => _busy;

  /// When the save last went up or came down, null before the first time.
  DateTime? get lastSynced => _lastSynced;

  /// Follows sign-in changes and pulls the save of a player who is already
  /// signed in. Called once, at start-up.
  void start() {
    if (!available) {
      return;
    }
    _changes = _auth.userChanges().listen((_) => notifyListeners());
    if (isSignedIn) {
      unawaited(sync());
    }
  }

  GoogleAuthProvider get _google =>
      GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});

  /// Signs in with Google, then brings the two saves together.
  Future<AccountOutcome> signInWithGoogle() async {
    if (!available) {
      return AccountOutcome.unavailable;
    }
    _setBusy(true);
    try {
      final current = _auth.currentUser;
      try {
        if (current != null && current.isAnonymous) {
          await current.linkWithProvider(_google);
        } else {
          await _auth.signInWithProvider(_google);
        }
      } on FirebaseAuthException catch (error) {
        if (!_alreadyLinkedElsewhere(error.code)) {
          rethrow;
        }
        // This Google account is already somebody: this player, on another
        // phone. Become that identity; the merge below keeps what this phone
        // had.
        final credential = error.credential;
        if (credential != null) {
          await _auth.signInWithCredential(credential);
        } else {
          await _auth.signInWithProvider(_google);
        }
      }
      await sync();
      return AccountOutcome.signedIn;
    } on FirebaseAuthException catch (error) {
      _log('sign-in failed: ${error.code} ${error.message}');
      return _wasCancelled(error.code)
          ? AccountOutcome.cancelled
          : AccountOutcome.failed;
    } catch (error) {
      _log('sign-in failed: $error');
      return AccountOutcome.failed;
    } finally {
      _setBusy(false);
    }
  }

  static bool _alreadyLinkedElsewhere(String code) =>
      code == 'credential-already-in-use' ||
      code == 'email-already-in-use' ||
      code == 'account-exists-with-different-credential';

  static bool _wasCancelled(String code) =>
      code == 'canceled' ||
      code == 'cancelled' ||
      code == 'web-context-canceled' ||
      code == 'web-context-cancelled' ||
      code == 'user-cancelled';

  /// Signs out of Google on this phone. Progress stays on the phone; the
  /// Daily Hunt carries on under a fresh anonymous identity the next time it
  /// needs one.
  Future<void> signOut() async {
    if (!available) {
      return;
    }
    _pending?.cancel();
    await push();
    await _auth.signOut();
    _lastSynced = null;
    _lastPushed = null;
    notifyListeners();
  }

  /// Deletes the account: the save, the player's row on the week and
  /// all-time tables, and the Firebase identity itself. Progress on this
  /// phone is left alone -- it was here before there was an account.
  ///
  /// Play requires an app that creates accounts to let players delete them
  /// from inside the app; this is that.
  Future<bool> deleteAccount() async {
    final user = _user;
    if (user == null || !isSignedIn) {
      return false;
    }
    _setBusy(true);
    _pending?.cancel();
    try {
      await _db.collection('saves').doc(user.uid).delete();
      await _db.collection('players').doc(user.uid).delete();
      try {
        await user.delete();
      } on FirebaseAuthException catch (error) {
        if (error.code != 'requires-recent-login') {
          rethrow;
        }
        await user.reauthenticateWithProvider(_google);
        await user.delete();
      }
      _lastSynced = null;
      _lastPushed = null;
      return true;
    } catch (error) {
      _log('account not deleted: $error');
      return false;
    } finally {
      _setBusy(false);
    }
  }

  DocumentReference<Map<String, dynamic>>? get _doc {
    final user = _user;
    if (user == null || !isSignedIn) {
      return null;
    }
    return _db.collection('saves').doc(user.uid);
  }

  /// Pulls the save, folds it into this phone's, and pushes the result back.
  Future<void> sync() async {
    final doc = _doc;
    if (doc == null) {
      return;
    }
    try {
      final snapshot = await doc.get();
      final cloud = snapshot.data();
      if (cloud != null) {
        await _save.mergeProgress(cloud);
        onMerged?.call();
      }
      await push();
    } catch (error) {
      _log('save not synced: $error');
    }
  }

  /// Pushes this phone's save a few seconds from now.
  void schedulePush() {
    if (!isSignedIn) {
      return;
    }
    _pending?.cancel();
    _pending = Timer(pushDelay, () => unawaited(push()));
  }

  /// Writes this phone's save to the account now.
  Future<void> push() async {
    final doc = _doc;
    if (doc == null) {
      return;
    }
    final progress = _save.exportProgress();
    final fingerprint = '${doc.id}:${jsonEncode(progress)}';
    if (fingerprint == _lastPushed) {
      return;
    }
    try {
      await doc.set({...progress, 'at': FieldValue.serverTimestamp()});
      _lastPushed = fingerprint;
      _lastSynced = DateTime.now();
      notifyListeners();
    } catch (error) {
      _log('save not pushed: $error');
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _pending?.cancel();
    _changes?.cancel();
    super.dispose();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[account] $message');
    }
  }
}
