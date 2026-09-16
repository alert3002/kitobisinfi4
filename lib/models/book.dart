import 'package:flutter/material.dart';

class BookItem {
  const BookItem({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.assetPdf,
    this.assetCover,
    this.coverUrl,
    required this.accent,
    this.remotePdfUrl,
    this.localFilePath,
    this.localCoverPath,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? assetPdf;
  final String? assetCover;
  final String? coverUrl;
  final Color accent;
  final String? remotePdfUrl;
  final String? localFilePath;
  final String? localCoverPath;

  bool get hasAssetPdf => assetPdf != null && assetPdf!.isNotEmpty;
  bool get hasAssetCover => assetCover != null && assetCover!.isNotEmpty;
  bool get hasLocalFile => localFilePath != null && localFilePath!.isNotEmpty;
  bool get hasLocalCover =>
      localCoverPath != null && localCoverPath!.isNotEmpty;
  bool get hasCoverUrl => coverUrl != null && coverUrl!.isNotEmpty;
  bool get hasRemotePdf => remotePdfUrl != null && remotePdfUrl!.isNotEmpty;

  BookItem copyWith({
    String? remotePdfUrl,
    String? localFilePath,
    String? localCoverPath,
  }) {
    return BookItem(
      id: id,
      title: title,
      subtitle: subtitle,
      assetPdf: assetPdf,
      assetCover: assetCover,
      coverUrl: coverUrl,
      accent: accent,
      remotePdfUrl: remotePdfUrl ?? this.remotePdfUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      localCoverPath: localCoverPath ?? this.localCoverPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'coverUrl': coverUrl,
        'remotePdfUrl': remotePdfUrl,
        'accent': accent.toARGB32(),
      };

  factory BookItem.fromJson(Map<String, dynamic> json) {
    return BookItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      remotePdfUrl: json['remotePdfUrl'] as String?,
      accent: Color((json['accent'] as num?)?.toInt() ?? 0xFF0F766E),
    );
  }
}

const _accents = <Color>[
  Color(0xFF0F766E),
  Color(0xFFB45309),
  Color(0xFFC2410C),
  Color(0xFF15803D),
  Color(0xFFB91C1C),
  Color(0xFF6D28D9),
  Color(0xFF0369A1),
];

Color accentForIndex(int index) => _accents[index.abs() % _accents.length];
