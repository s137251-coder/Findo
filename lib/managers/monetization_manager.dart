import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'save_manager.dart';

/// AdMob unit ids.
///
/// These are Google's official test units, which is what a build must use
/// until the real app is registered in AdMob. Swap the four constants below
/// (and the app ids in AndroidManifest.xml and Info.plist) before release;
/// nothing else in the codebase refers to an ad unit.
class AdUnitIds {
  const AdUnitIds._();

  static const _androidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _iosInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const _androidRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  static String get interstitial =>
      Platform.isIOS ? _iosInterstitial : _androidInterstitial;

  static String get rewarded => Platform.isIOS ? _iosRewarded : _androidRewarded;
}

/// Devices that AdMob should treat as test devices.
///
/// Once [AdUnitIds] carries real units, every ad request from a device not on
/// this list is a real impression. A handful of testers replaying the same
/// build is exactly the pattern AdMob flags as invalid traffic, and the
/// penalty lands on the ad account rather than the app. Listing a device here
/// keeps the real ad code path -- real unit ids, real load and reward
/// callbacks -- while the impressions stay uncounted.
///
/// Supplied at build time so no real device id is ever committed:
///
/// ```
/// flutter build appbundle --dart-define=FINDO_AD_TEST_DEVICES=ID1,ID2
/// ```
///
/// A device prints its own id the first time it requests an ad. Run a debug
/// build, ask for a hint, and the SDK logs a line naming the id to add here.
class AdTestDevices {
  const AdTestDevices._();

  static const _raw = String.fromEnvironment('FINDO_AD_TEST_DEVICES');

  /// Trimmed and de-duplicated, so a trailing comma or a stray space in the
  /// build command cannot produce an empty id the SDK rejects.
  static List<String> parse(String raw) => raw
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  static List<String> get ids => parse(_raw);
}

/// Store product identifiers. They must match the entries created in Google
/// Play Console and App Store Connect.
class StoreProducts {
  const StoreProducts._();

  static const removeAds = 'findo_remove_ads';
  static const hintPack = 'findo_hint_pack_10';

  /// Hints granted by one purchase of [hintPack].
  static const hintPackSize = 10;

  static const all = {removeAds, hintPack};
}

/// Ads, purchases and the consent that has to come before either.
///
/// Order matters on iOS: App Tracking Transparency is requested first, then
/// UMP consent, and only then is the ad SDK initialized.
class MonetizationManager extends ChangeNotifier {
  MonetizationManager(this._saveManager);

  /// An interstitial is offered after every this-many finished levels.
  static const interstitialEveryNLevels = 2;

  final SaveManager _saveManager;
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  bool _adsInitialized = false;
  bool _storeAvailable = false;
  bool _canRequestAds = false;
  int _levelsSinceInterstitial = 0;
  List<ProductDetails> _products = const [];
  String? _lastStoreMessageKey;

  bool get adsRemoved => _saveManager.adsRemoved;

  bool get storeAvailable => _storeAvailable;

  bool get rewardedAdReady => _rewarded != null;

  int get hintCount => _saveManager.hintCount;

  List<ProductDetails> get products => List.unmodifiable(_products);

  /// Translation key describing the last store outcome, consumed by the UI.
  String? takeStoreMessageKey() {
    final message = _lastStoreMessageKey;
    _lastStoreMessageKey = null;
    return message;
  }

  ProductDetails? productById(String id) {
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    await _requestTrackingAuthorization();
    await _gatherConsent();
    await _initializeAds();
    await _initializeStore();
  }

  // -- privacy -------------------------------------------------------------

  Future<void> _requestTrackingAuthorization() async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (error) {
      _log('ATT request failed: $error');
    }
  }

  /// Runs the Google UMP flow, which covers GDPR consent in the EEA and UK.
  Future<void> _gatherConsent() async {
    final completer = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(tagForUnderAgeOfConsent: false),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((error) {
              if (error != null) {
                _log('consent form dismissed with error: ${error.message}');
              }
            });
          } catch (error) {
            _log('consent form failed: $error');
          }
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        (FormError error) {
          _log('consent update failed: ${error.message}');
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );
      await completer.future.timeout(const Duration(seconds: 12));
    } catch (error) {
      _log('consent flow failed: $error');
    }
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (error) {
      _canRequestAds = false;
    }
  }

  /// Reopens the consent form so the player can change their mind, as the
  /// privacy options requirement demands.
  Future<void> showPrivacyOptions() async {
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      if (status == PrivacyOptionsRequirementStatus.required) {
        await ConsentForm.showPrivacyOptionsForm((FormError? error) {
          if (error != null) {
            _log('privacy options failed: ${error.message}');
          }
        });
      }
    } catch (error) {
      _log('privacy options unavailable: $error');
    }
  }

  // -- ads -----------------------------------------------------------------

  Future<void> _initializeAds() async {
    if (!_canRequestAds || adsRemoved) {
      return;
    }
    try {
      // Before initialize, so the very first request is already covered.
      final testDevices = AdTestDevices.ids;
      if (testDevices.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: testDevices),
        );
        _log('ads: ${testDevices.length} test device(s) registered');
      }
      await MobileAds.instance.initialize();
      _adsInitialized = true;
      unawaited(_loadInterstitial());
      unawaited(loadRewarded());
    } catch (error) {
      _log('ad init failed: $error');
    }
  }

  Future<void> _loadInterstitial() async {
    if (!_adsInitialized || adsRemoved || _interstitial != null) {
      return;
    }
    final completer = Completer<void>();
    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onAdFailedToLoad: (error) {
          _log('interstitial failed: ${error.message}');
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      ),
    );
    await completer.future;
  }

  /// Loads a rewarded ad so the hint button has something to show later.
  Future<void> loadRewarded() async {
    if (!_adsInitialized || _rewarded != null) {
      return;
    }
    final completer = Completer<void>();
    RewardedAd.load(
      adUnitId: AdUnitIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          notifyListeners();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onAdFailedToLoad: (error) {
          _log('rewarded failed: ${error.message}');
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      ),
    );
    await completer.future;
  }

  /// Counts a finished level and shows an interstitial when one is due.
  Future<void> onLevelFinished() async {
    if (adsRemoved || !_adsInitialized) {
      return;
    }
    _levelsSinceInterstitial++;
    if (_levelsSinceInterstitial < interstitialEveryNLevels) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      unawaited(_loadInterstitial());
      return;
    }
    _levelsSinceInterstitial = 0;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_loadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(_loadInterstitial());
      },
    );
    await ad.show();
  }

  /// Shows a rewarded ad and reports whether the reward was earned.
  Future<bool> showRewardedForHint() async {
    final ad = _rewarded;
    if (ad == null) {
      unawaited(loadRewarded());
      return false;
    }
    _rewarded = null;
    notifyListeners();
    var earned = false;
    final dismissed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(loadRewarded());
        if (!dismissed.isCompleted) {
          dismissed.complete();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(loadRewarded());
        if (!dismissed.isCompleted) {
          dismissed.complete();
        }
      },
    );
    await ad.show(
      onUserEarnedReward: (_, reward) {
        earned = true;
      },
    );
    await dismissed.future;
    if (earned) {
      await _saveManager.addHints(1);
      notifyListeners();
    }
    return earned;
  }

  // -- purchases -----------------------------------------------------------

  Future<void> _initializeStore() async {
    try {
      _storeAvailable = await _iap.isAvailable();
    } catch (error) {
      _storeAvailable = false;
      _log('store check failed: $error');
    }
    if (!_storeAvailable) {
      notifyListeners();
      return;
    }
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object error) => _log('purchase stream error: $error'),
    );
    try {
      final response = await _iap.queryProductDetails(StoreProducts.all);
      _products = response.productDetails;
    } catch (error) {
      _log('product query failed: $error');
    }
    notifyListeners();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          _lastStoreMessageKey = 'shop.purchaseFailed';
          notifyListeners();
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grantEntitlement(purchase);
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _grantEntitlement(PurchaseDetails purchase) async {
    switch (purchase.productID) {
      case StoreProducts.removeAds:
        await _saveManager.setAdsRemoved(true);
        await _disposeAds();
      case StoreProducts.hintPack:
        // Restores of a consumable must not stack hints a second time.
        if (purchase.status == PurchaseStatus.purchased) {
          await _saveManager.addHints(StoreProducts.hintPackSize);
        }
    }
    notifyListeners();
  }

  Future<bool> buyRemoveAds() => _buy(StoreProducts.removeAds, consumable: false);

  Future<bool> buyHintPack() => _buy(StoreProducts.hintPack, consumable: true);

  Future<bool> _buy(String productId, {required bool consumable}) async {
    final product = productById(productId);
    if (!_storeAvailable || product == null) {
      _lastStoreMessageKey = 'shop.unavailable';
      notifyListeners();
      return false;
    }
    final param = PurchaseParam(productDetails: product);
    try {
      return consumable
          ? await _iap.buyConsumable(purchaseParam: param)
          : await _iap.buyNonConsumable(purchaseParam: param);
    } catch (error) {
      _log('purchase failed: $error');
      _lastStoreMessageKey = 'shop.purchaseFailed';
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_storeAvailable) {
      _lastStoreMessageKey = 'shop.unavailable';
      notifyListeners();
      return;
    }
    try {
      await _iap.restorePurchases();
      _lastStoreMessageKey = 'shop.restored';
    } catch (error) {
      _log('restore failed: $error');
      _lastStoreMessageKey = 'shop.purchaseFailed';
    }
    notifyListeners();
  }

  // -- hints ---------------------------------------------------------------

  /// Spends one stored hint. False means the player has none left.
  Future<bool> consumeHint() async {
    final consumed = await _saveManager.consumeHint();
    if (consumed) {
      notifyListeners();
    }
    return consumed;
  }

  Future<void> _disposeAds() async {
    _interstitial?.dispose();
    _interstitial = null;
    _rewarded?.dispose();
    _rewarded = null;
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _interstitial?.dispose();
    _rewarded?.dispose();
    super.dispose();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('MonetizationManager: $message');
    }
  }
}
