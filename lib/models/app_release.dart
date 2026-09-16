class AppRelease {
  const AppRelease({
    required this.versionName,
    required this.versionCode,
    required this.title,
    required this.message,
    this.androidUrl,
    this.iosUrl,
    this.forceUpdate = false,
  });

  final String versionName;
  final int versionCode;
  final String title;
  final String message;
  final String? androidUrl;
  final String? iosUrl;
  final bool forceUpdate;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    String? url(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    return AppRelease(
      versionName: (json['version_name'] as String?)?.trim() ?? '',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Версияи нав баромад',
      message: (json['message'] as String?)?.trim().isNotEmpty == true
          ? json['message'] as String
          : 'Лутфан барномаро навсозӣ кунед.',
      androidUrl: url(json['android_url']),
      iosUrl: url(json['ios_url']),
      forceUpdate: json['force_update'] == true,
    );
  }
}

class AppNotice {
  const AppNotice({
    required this.id,
    required this.title,
    required this.body,
    this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final DateTime? createdAt;

  factory AppNotice.fromJson(Map<String, dynamic> json) {
    return AppNotice(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?)?.trim() ?? '',
      body: (json['body'] as String?)?.trim() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
