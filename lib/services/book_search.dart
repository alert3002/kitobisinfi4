import 'package:pdfrx/pdfrx.dart';

import '../models/book.dart';
import 'catalog_service.dart';
import 'tajik_text.dart';

class TextHit {
  const TextHit({
    required this.book,
    required this.page,
    required this.snippet,
    required this.matchStart,
    required this.matchLength,
  });

  final BookItem book;
  final int page;
  final String snippet;
  final int matchStart;
  final int matchLength;
}

class BookSearch {
  BookSearch._();
  static final instance = BookSearch._();

  final _pageTexts = <String, List<String>>{};
  int _token = 0;

  List<BookItem> get _books => CatalogService.instance.books;

  List<BookItem> booksByTitle(String query) {
    final q = foldTajik(query.trim());
    if (q.isEmpty) return _books;
    return _books.where((b) => foldTajik(b.title).contains(q)).toList();
  }

  Future<List<TextHit>> searchInPages(
    String query, {
    void Function(List<TextHit> soFar)? onPartial,
  }) async {
    final raw = query.trim();
    if (raw.length < 2) return const [];
    final token = ++_token;
    final needle = foldTajik(raw);
    final hits = <TextHit>[];

    await pdfrxFlutterInitialize();

    for (final book in _books) {
      if (token != _token) return hits;
      try {
        final pages = await _pagesOf(book);
        var perBook = 0;
        for (var i = 0; i < pages.length; i++) {
          if (token != _token) return hits;
          final text = pages[i];
          final folded = foldTajik(text);
          final index = folded.indexOf(needle);
          if (index < 0) continue;
          hits.add(
            TextHit(
              book: book,
              page: i + 1,
              snippet: _snippet(text, index, needle.length),
              matchStart: index,
              matchLength: needle.length,
            ),
          );
          perBook += 1;
          if (perBook >= 4 || hits.length >= 24) break;
        }
        onPartial?.call(List.unmodifiable(hits));
        if (hits.length >= 24) break;
      } catch (_) {
        continue;
      }
    }
    return hits;
  }

  Future<List<String>> _pagesOf(BookItem book) async {
    final cached = _pageTexts[book.id];
    if (cached != null) return cached;

    late final PdfDocument doc;
    if (book.hasLocalFile) {
      doc = await PdfDocument.openFile(book.localFilePath!);
    } else if (book.hasAssetPdf) {
      doc = await PdfDocument.openAsset(book.assetPdf!);
    } else if (book.hasRemotePdf) {
      doc = await PdfDocument.openUri(Uri.parse(book.remotePdfUrl!));
    } else {
      return const [];
    }
    final pages = <String>[];
    try {
      for (final page in doc.pages) {
        final raw = await page.loadText();
        pages.add(raw?.fullText ?? '');
      }
    } finally {
      await doc.dispose();
    }
    _pageTexts[book.id] = pages;
    return pages;
  }

  String _snippet(String text, int index, int len) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final folded = foldTajik(compact);
    final start = (index - 28).clamp(0, folded.length);
    final end = (index + len + 36).clamp(0, folded.length);
    var piece = compact.substring(
      start.clamp(0, compact.length),
      end.clamp(0, compact.length),
    ).trim();
    if (start > 0) piece = '…$piece';
    if (end < compact.length) piece = '$piece…';
    return piece;
  }
}
