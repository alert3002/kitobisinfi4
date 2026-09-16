class SchoolGrade {
  const SchoolGrade({
    required this.number,
    required this.name,
    this.androidUrl,
    this.iosUrl,
  });

  final int number;
  final String name;
  final String? androidUrl;
  final String? iosUrl;

  bool get hasAndroidLink => androidUrl != null && androidUrl!.isNotEmpty;
  bool get hasIosLink => iosUrl != null && iosUrl!.isNotEmpty;

  static List<SchoolGrade> fallback() => [
        for (var n = 1; n <= 11; n++) SchoolGrade(number: n, name: 'Синфи $n'),
      ];
}
