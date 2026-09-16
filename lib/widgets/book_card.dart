import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/book_cache.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.cacheWidth,
  });

  final BookItem book;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: book.accent.withValues(alpha: 0.15),
      child: Icon(
        Icons.menu_book_rounded,
        size: 42,
        color: book.accent,
      ),
    );
    if (book.hasLocalCover) {
      return Image.file(
        File(book.localCoverPath!),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    if (book.hasAssetCover) {
      return Image.asset(
        book.assetCover!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    if (book.hasCoverUrl) {
      return Image.network(
        book.coverUrl!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return placeholder;
  }
}

class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.page,
    required this.onOpen,
    this.onFavorite,
  });

  final BookItem book;
  final int page;
  final VoidCallback onOpen;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (MediaQuery.sizeOf(context).width / 2 * dpr).round();
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFC9BBA8), width: 1.2),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppTheme.teal.withValues(alpha: 0.18),
        highlightColor: AppTheme.teal.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BookCover(book: book, cacheWidth: cacheW),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onFavorite,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                ProgressService.instance.isFavorite(book.id)
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 18,
                                color: const Color(0xFFD4A017),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: BookCache.instance.progressOf(book.id),
                        builder: (context, value, child) {
                          if (!BookCache.instance.isDownloading(book.id)) {
                            return const SizedBox.shrink();
                          }
                          return ColoredBox(
                            color: const Color(0x88000000),
                            child: Center(
                              child: Text(
                                value == 0 ? '…' : '$value%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (page > 1)
                        Positioned(
                          right: 5,
                          bottom: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.tealDark.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$page',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (ProgressService.instance.pageCountFor(book.id) > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ProgressService.instance.percentFor(book.id),
                      minHeight: 4,
                      backgroundColor: const Color(0xFFE8DDCC),
                      color: AppTheme.teal,
                    ),
                  ),
                ),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  height: 1.15,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
