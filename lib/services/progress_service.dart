import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class ProgressService {
  ProgressService._();
  static final instance = ProgressService._();

  static const _lastBookKey = 'last_book_id';
  static const _lastInterstitialKey = 'last_interstitial_at';
  static const _nightKey = 'reader_night_mode';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  int pageFor(String bookId) => _prefs?.getInt('page_$bookId') ?? 1;

  Future<void> savePage(String bookId, int page) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setInt('page_$bookId', page);
    await prefs.setString(_lastBookKey, bookId);
  }

  String? get lastBookId => _prefs?.getString(_lastBookKey);

  int pageCountFor(String bookId) => _prefs?.getInt('pagecount_$bookId') ?? 0;

  Future<void> savePageCount(String bookId, int count) async {
    if (count < 1) return;
    await _prefs?.setInt('pagecount_$bookId', count);
  }

  double percentFor(String bookId) {
    final total = pageCountFor(bookId);
    if (total < 1) return 0;
    return (pageFor(bookId) / total).clamp(0, 1);
  }

  bool isFavorite(String bookId) => _prefs?.getBool('fav_$bookId') ?? false;

  Future<void> toggleFavorite(String bookId) async {
    await _prefs?.setBool('fav_$bookId', !isFavorite(bookId));
  }

  List<int> bookmarksFor(String bookId) {
    final raw = _prefs?.getStringList('bookmarks_$bookId') ?? const [];
    final pages = raw.map(int.tryParse).whereType<int>().toSet().toList()
      ..sort();
    return pages;
  }

  bool isBookmarked(String bookId, int page) =>
      bookmarksFor(bookId).contains(page);

  Future<void> toggleBookmark(String bookId, int page) async {
    final pages = bookmarksFor(bookId).toSet();
    if (!pages.add(page)) pages.remove(page);
    final sorted = pages.toList()..sort();
    await _prefs?.setStringList(
      'bookmarks_$bookId',
      sorted.map((p) => '$p').toList(),
    );
  }

  String noteFor(String bookId) => _prefs?.getString('note_$bookId') ?? '';

  Future<void> saveNote(String bookId, String note) async {
    await _prefs?.setString('note_$bookId', note.trim());
  }

  bool get nightMode => _prefs?.getBool(_nightKey) ?? false;

  Future<void> setNightMode(bool value) async {
    await _prefs?.setBool(_nightKey, value);
  }

  DateTime? get lastInterstitialAt {
    final raw = _prefs?.getInt(_lastInterstitialKey);
    if (raw == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }

  Future<void> markInterstitialShown([DateTime? at]) async {
    await _prefs?.setInt(
      _lastInterstitialKey,
      (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  int get lastSeenNoticeId => _prefs?.getInt('last_seen_notice_id') ?? 0;

  Future<void> markNoticesSeen(int maxId) async {
    final current = lastSeenNoticeId;
    if (maxId > current) {
      await _prefs?.setInt('last_seen_notice_id', maxId);
    }
  }

  int get dismissedUpdateCode => _prefs?.getInt('dismissed_update_code') ?? 0;

  Future<void> dismissUpdate(int versionCode) async {
    await _prefs?.setInt('dismissed_update_code', versionCode);
  }

  String? get catalogCache => _prefs?.getString('catalog_cache_v1_$kGrade');

  Future<void> saveCatalogCache(String json) async {
    await _prefs?.setString('catalog_cache_v1_$kGrade', json);
  }
}
