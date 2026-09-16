import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';

class BookCache {
  BookCache._();
  static final instance = BookCache._();

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5),
      followRedirects: true,
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );

  final _inflightPdf = <String, Future<BookItem>>{};
  final _tokens = <String, CancelToken>{};
  final _progress = <String, ValueNotifier<int>>{};

  bool isDownloading(String bookId) => _inflightPdf.containsKey(bookId);

  ValueNotifier<int> progressOf(String bookId) {
    return _progress.putIfAbsent(bookId, () => ValueNotifier<int>(0));
  }

  void cancel(String bookId) {
    final token = _tokens[bookId];
    if (token != null && !token.isCancelled) {
      token.cancel('user');
    }
  }

  Future<String> _dir(String name) async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/$name');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder.path;
  }

  String _https(String url) {
    if (url.startsWith('http://')) return 'https://${url.substring(7)}';
    return url;
  }

  Future<bool> _isCompletePdf(File file) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length < 1024) return false;
    final raf = await file.open();
    try {
      final head = await raf.read(5);
      if (String.fromCharCodes(head) != '%PDF-') return false;
      final tailSize = length < 2048 ? length : 2048;
      await raf.setPosition(length - tailSize);
      final tail = String.fromCharCodes(await raf.read(tailSize));
      return tail.contains('%%EOF');
    } catch (_) {
      return false;
    } finally {
      await raf.close();
    }
  }

  Future<String?> pdfPath(String bookId) async {
    final dir = await _dir('books');
    final file = File('$dir/$bookId.pdf');
    if (await _isCompletePdf(file)) return file.path;
    return null;
  }

  Future<bool> hasValidPdf(String bookId) async =>
      await pdfPath(bookId) != null;

  Future<void> deletePdf(String bookId) async {
    cancel(bookId);
    final dir = await _dir('books');
    for (final name in ['$bookId.pdf', '$bookId.pdf.part']) {
      final file = File('$dir/$name');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<String?> coverPath(String bookId) async {
    final dir = await _dir('covers');
    for (final ext in const ['jpg', 'jpeg', 'png', 'webp']) {
      final file = File('$dir/$bookId.$ext');
      if (await file.exists() && await file.length() > 100) return file.path;
    }
    return null;
  }

  Future<BookItem> attachLocal(BookItem book) async {
    return book.copyWith(
      localFilePath: await pdfPath(book.id),
      localCoverPath: await coverPath(book.id),
    );
  }

  static String formatBytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb < 0.1) return '${(bytes / 1024).ceil()} КБ';
    return '${mb.toStringAsFixed(1)} МБ';
  }

  Future<int?> probePdfBytes(BookItem book) async {
    var url = book.remotePdfUrl;
    if (url == null || url.isEmpty) return null;
    url = _https(url);
    try {
      final res = await _dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final len = res.headers.value('content-length');
      final parsed = len == null ? null : int.tryParse(len);
      if (parsed != null && parsed > 0) return parsed;
    } catch (_) {}
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(
          followRedirects: true,
          headers: const {'Range': 'bytes=0-0'},
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final range = res.headers.value('content-range');
      final match = range == null
          ? null
          : RegExp(r'/(\d+)\s*$').firstMatch(range);
      if (match != null) return int.tryParse(match.group(1)!);
    } catch (_) {}
    return null;
  }

  Future<BookItem> ensurePdf(BookItem book) async {
    final existing = await pdfPath(book.id);
    if (existing != null) {
      return book.copyWith(localFilePath: existing);
    }
    final pending = _inflightPdf[book.id];
    if (pending != null) return pending;

    final token = CancelToken();
    _tokens[book.id] = token;
    progressOf(book.id).value = 0;

    final future = _downloadPdf(book, token);
    _inflightPdf[book.id] = future;
    try {
      return await future;
    } finally {
      _inflightPdf.remove(book.id);
      _tokens.remove(book.id);
    }
  }

  Future<BookItem> _downloadPdf(BookItem book, CancelToken token) async {
    var url = book.remotePdfUrl;
    if (url == null || url.isEmpty) {
      throw Exception('PDF нест');
    }
    url = _https(url);
    final dir = await _dir('books');
    final dest = File('$dir/${book.id}.pdf');
    final part = File('$dir/${book.id}.pdf.part');
    if (await part.exists()) {
      await part.delete();
    }
    final notifier = progressOf(book.id);
    try {
      await _dio.download(
        url,
        part.path,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            notifier.value = ((received / total) * 100).round().clamp(0, 100);
          }
        },
      );
      if (!await _isCompletePdf(part)) {
        if (await part.exists()) await part.delete();
        throw Exception('PDF нодуруст');
      }
      if (await dest.exists()) await dest.delete();
      await part.rename(dest.path);
    } catch (e) {
      if (await part.exists()) {
        await part.delete();
      }
      rethrow;
    }
    notifier.value = 100;
    return book.copyWith(localFilePath: dest.path);
  }

  Future<BookItem> ensureCover(BookItem book) async {
    final existing = await coverPath(book.id);
    if (existing != null) return book.copyWith(localCoverPath: existing);
    var url = book.coverUrl;
    if (url == null || url.isEmpty) return book;
    url = _https(url);
    final ext = url.contains('.png')
        ? 'png'
        : url.contains('.webp')
            ? 'webp'
            : 'jpg';
    final dir = await _dir('covers');
    final dest = '$dir/${book.id}.$ext';
    try {
      await _dio.download(url, dest);
      return book.copyWith(localCoverPath: dest);
    } catch (_) {
      return book;
    }
  }
}
