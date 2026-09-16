class AdIds {
  const AdIds({
    required this.adsEnabled,
    required this.bannerId,
    required this.interstitialId,
  });

  final bool adsEnabled;
  final String bannerId;
  final String interstitialId;

  static const off = AdIds(
    adsEnabled: false,
    bannerId: '',
    interstitialId: '',
  );

  factory AdIds.test({required bool android}) {
    return AdIds(
      adsEnabled: true,
      bannerId: android
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716',
      interstitialId: android
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910',
    );
  }
}
