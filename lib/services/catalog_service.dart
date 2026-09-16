import 'dart:async';
import 'dart:convert';

import '../config.dart';
import '../models/book.dart';
import '../models/school_grade.dart';
import 'api_service.dart';
import 'book_cache.dart';
import 'progress_service.dart';

class CatalogService {
  CatalogService._();
  static final instance = CatalogService._();

  final _api = ApiService();
  List<SchoolGrade> grades = SchoolGrade.fallback();
  List<BookItem> books = const [];
  String className = kDefaultClassName;
  bool loading = true;
  String? error;

  Future<void> refresh() async {
    await _restoreCache();
    loading = books.isEmpty;
    try {
      await _loadClasses();
      await _loadBooks();
      await _attachLocal();
      await _saveCache();
      error = null;
      unawaited(_prefetchCovers());
    } catch (e) {
      if (books.isEmpty) {
        error = 'Сервер пайваст нашуд: $kApiBaseUrl';
      }
    } finally {
      loading = false;
    }
  }

  Future<void> _restoreCache() async {
    final raw = ProgressService.instance.catalogCache;
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      className = (data['className'] as String?)?.trim().isNotEmpty == true
          ? data['className'] as String
          : className;
      final gradeRows = data['grades'] as List? ?? const [];
      final parsedGrades = <SchoolGrade>[];
      for (final row in gradeRows) {
        if (row is! Map) continue;
        final number = (row['number'] as num?)?.toInt();
        final name = (row['name'] as String?)?.trim();
        if (number == null) continue;
        parsedGrades.add(
          SchoolGrade(
            number: number,
            name: (name == null || name.isEmpty) ? 'Синфи $number' : name,
            androidUrl: row['androidUrl'] as String?,
            iosUrl: row['iosUrl'] as String?,
          ),
        );
      }
      if (parsedGrades.isNotEmpty) grades = parsedGrades;
      final bookRows = data['books'] as List? ?? const [];
      final parsedBooks = <BookItem>[];
      for (final row in bookRows) {
        if (row is! Map) continue;
        final item = BookItem.fromJson(Map<String, dynamic>.from(row));
        if (item.id.isEmpty || item.title.isEmpty) continue;
        parsedBooks.add(await BookCache.instance.attachLocal(item));
      }
      if (parsedBooks.isNotEmpty) books = parsedBooks;
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    final payload = {
      'className': className,
      'grades': [
        for (final g in grades)
          {
            'number': g.number,
            'name': g.name,
            'androidUrl': g.androidUrl,
            'iosUrl': g.iosUrl,
          },
      ],
      'books': [for (final b in books) b.toJson()],
    };
    await ProgressService.instance.saveCatalogCache(jsonEncode(payload));
  }

  Future<void> _attachLocal() async {
    final next = <BookItem>[];
    for (final book in books) {
      next.add(await BookCache.instance.attachLocal(book));
    }
    books = next;
  }

  Future<void> _prefetchCovers() async {
    final next = <BookItem>[];
    for (final book in books) {
      next.add(await BookCache.instance.ensureCover(book));
    }
    books = next;
    await _saveCache();
  }

  void replaceBook(BookItem book) {
    books = [for (final item in books) item.id == book.id ? book : item];
    unawaited(_saveCache());
  }

  Future<void> _loadClasses() async {
    final rows = await _api.fetchClasses();
    if (rows.isEmpty) return;
    final parsed = <SchoolGrade>[];
    for (final row in rows) {
      final number = (row['number'] as num?)?.toInt();
      final name = (row['name'] as String?)?.trim();
      if (number == null || number < 1 || number > 11) continue;
      parsed.add(
        SchoolGrade(
          number: number,
          name: (name == null || name.isEmpty) ? 'Синфи $number' : name,
          androidUrl: _optionalUrl(row['android_store_url']),
          iosUrl: _optionalUrl(row['ios_store_url']),
        ),
      );
    }
    if (parsed.isEmpty) return;
    parsed.sort((a, b) => a.number.compareTo(b.number));
    grades = parsed;
    final current = parsed.where((g) => g.number == kGrade);
    className = current.isEmpty ? kDefaultClassName : current.first.name;
  }

  Future<void> _loadBooks() async {
    final rows = await _api.fetchGradeBooks(kGrade);
    final parsed = <BookItem>[];
    for (var i = 0; i < rows.length; i++) {
      final item = _bookFromApi(rows[i], i);
      if (item != null) parsed.add(item);
    }
    books = parsed;
  }

  BookItem? _bookFromApi(Map<String, dynamic> row, int index) {
    final apiId = row['id'];
    final title = (row['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;
    return BookItem(
      id: 'api_$apiId',
      title: title,
      coverUrl: _optionalUrl(row['cover_url']),
      remotePdfUrl: _optionalUrl(row['pdf_url']),
      accent: accentForIndex(index),
    );
  }
}

String? _optionalUrl(dynamic value) {
  if (value == null) return null;
  var text = value.toString().trim();
  if (text.isEmpty) return null;
  if (text.startsWith('http://')) {
    text = 'https://${text.substring(7)}';
  }
  return text;
}
