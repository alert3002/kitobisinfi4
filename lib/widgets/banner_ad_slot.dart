import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_service.dart';

class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key});

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AdsService.instance.addListener(_onAdsChanged);
    _tryLoad();
  }

  void _onAdsChanged() {
    if (!AdsService.instance.adsEnabled) {
      _ad?.dispose();
      _ad = null;
      if (mounted) setState(() => _loaded = false);
      return;
    }
    final unit = AdsService.instance.ids.bannerId;
    if (_ad != null && _ad!.adUnitId == unit && _loaded) return;
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _tryLoad();
  }

  void _tryLoad() {
    if (_ad != null) return;
    if (!AdsService.instance.adsEnabled) return;
    final banner = BannerAd(
      size: AdSize.banner,
      adUnitId: AdsService.instance.ids.bannerId,
      request: AdsService.instance.adRequest,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    )..load();
    _ad = banner;
  }

  @override
  void dispose() {
    AdsService.instance.removeListener(_onAdsChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
