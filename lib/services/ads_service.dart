import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import '../models/ad_ids.dart';
import 'api_service.dart';
import 'progress_service.dart';

class AdsService extends ChangeNotifier {
  AdsService._();
  static final instance = AdsService._();

  final _api = ApiService();
  AdIds _ids = AdIds.off;
  bool _ready = false;
  InterstitialAd? _interstitial;
  List<String> _keywords = List<String>.from(kAdKeywords);

  AdIds get ids => _ids;
  List<String> get keywords => _keywords;
  AdRequest get adRequest => AdRequest(keywords: _keywords);

  bool get adsEnabled =>
      _ready &&
      _ids.adsEnabled &&
      _ids.bannerId.isNotEmpty;

  bool get interstitialEnabled =>
      _ready && _ids.adsEnabled && _ids.interstitialId.isNotEmpty;

  Future<void> init() async {
    if (!isMobileAdsPlatform) {
      _ready = true;
      notifyListeners();
      return;
    }
    try {
      await MobileAds.instance.initialize();
      await refresh();
      if (!kDebugMode) {
        final last = ProgressService.instance.lastInterstitialAt;
        if (last == null) {
          await ProgressService.instance.markInterstitialShown();
        }
      }
    } catch (e) {
      debugPrint('Ads init: $e');
      _ids = AdIds.off;
      _ready = true;
      notifyListeners();
    }
  }

  void setBookContext(String title, {String subtitle = ''}) {
    final extra = <String>[
      title.trim(),
      if (subtitle.trim().isNotEmpty) subtitle.trim(),
    ];
    _keywords = {...kAdKeywords, ...extra}.toList();
    notifyListeners();
  }

  void clearBookContext() {
    _keywords = List<String>.from(kAdKeywords);
    notifyListeners();
  }

  Duration get _interstitialInterval =>
      kDebugMode ? Duration.zero : kInterstitialInterval;

  Future<void> refresh() async {
    if (!isMobileAdsPlatform) return;
    _ids = await _api.fetchAds(android: Platform.isAndroid);
    _ready = true;
    notifyListeners();
    if (interstitialEnabled) {
      unawaited(_loadInterstitial());
    } else {
      _interstitial?.dispose();
      _interstitial = null;
    }
  }

  Future<void> maybeShowInterstitial() async {
    if (!interstitialEnabled) return;
    final last = ProgressService.instance.lastInterstitialAt;
    if (last != null &&
        DateTime.now().difference(last) < _interstitialInterval) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      await _loadInterstitial();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
    );
    await ad.show();
    await ProgressService.instance.markInterstitialShown();
    _interstitial = null;
  }

  Future<void> _loadInterstitial() async {
    if (!interstitialEnabled) return;
    await InterstitialAd.load(
      adUnitId: _ids.interstitialId,
      request: adRequest,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed: $error');
          _interstitial = null;
        },
      ),
    );
  }
}
