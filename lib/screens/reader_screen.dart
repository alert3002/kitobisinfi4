import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/book.dart';
import '../services/ads_service.dart';
import '../services/book_cache.dart';
import '../services/progress_service.dart';
import '../services/tajik_text.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_slot.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.book,
    this.initialPage,
    this.initialQuery,
  });

  final BookItem book;
  final int? initialPage;
  final String? initialQuery;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _pdfController = PdfViewerController();
  PdfTextSearcher? _searcher;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  bool _showSearch = false;
  bool _ready = false;
  bool _night = ProgressService.instance.nightMode;
  int _page = 1;
  int _pageCount = 1;
  late final PdfDocumentRef _pdfRef;

  @override
  void initState() {
    super.initState();
    _pdfRef = _documentRef(widget.book);
    AdsService.instance.setBookContext(
      widget.book.title,
      subtitle: widget.book.subtitle,
    );
    WakelockPlus.enable();
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty) {
      _showSearch = true;
      _searchController.text = q;
    }
  }

  @override
  void dispose() {
    AdsService.instance.clearBookContext();
    WakelockPlus.disable();
    _debounce?.cancel();
    _searcher?.removeListener(_onSearch);
    _searcher?.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  PdfDocumentRef _documentRef(BookItem book) {
    if (book.hasLocalFile) {
      return PdfDocumentRefFile(book.localFilePath!);
    }
    if (book.hasAssetPdf) {
      return PdfDocumentRefAsset(book.assetPdf!);
    }
    if (book.hasRemotePdf) {
      return PdfDocumentRefUri(Uri.parse(book.remotePdfUrl!));
    }
    return PdfDocumentRefUri(Uri.parse('about:blank'));
  }

  void _onSearch() {
    if (mounted) setState(() {});
  }

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    if (!mounted) return;
    _searcher?.removeListener(_onSearch);
    _searcher?.dispose();
    final searcher = PdfTextSearcher(controller)..addListener(_onSearch);
    _searcher = searcher;

    final count = document.pages.isEmpty ? 1 : document.pages.length;
    final saved = widget.initialPage ??
        ProgressService.instance.pageFor(widget.book.id);
    setState(() {
      _pageCount = count;
      _page = (controller.pageNumber ?? saved).clamp(1, count);
      _ready = true;
    });
    unawaited(ProgressService.instance.savePageCount(widget.book.id, count));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitWidth();
    });

    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      searcher.startTextSearch(
        tajikSearchPattern(q),
        caseInsensitive: true,
      );
    }
  }

  int? _initialPage(PdfDocument document, PdfViewerController controller) {
    final count = document.pages.length;
    if (count <= 0) return 1;
    final saved = widget.initialPage ??
        ProgressService.instance.pageFor(widget.book.id);
    return saved.clamp(1, count);
  }

  Future<void> _fitWidth() async {
    if (!_pdfController.isReady) return;
    try {
      final matrix = _pdfController.calcMatrixFitWidthForPage(pageNumber: _page);
      if (matrix != null) {
        await _pdfController.goTo(matrix, duration: Duration.zero);
      }
    } catch (_) {}
  }

  Future<void> _zoomIn() async {
    if (!_pdfController.isReady) return;
    await _pdfController.zoomUp(loop: false);
  }

  Future<void> _zoomOut() async {
    if (!_pdfController.isReady) return;
    await _pdfController.zoomDown(loop: false);
  }

  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null) return;
    setState(() => _page = pageNumber);
    ProgressService.instance.savePage(widget.book.id, pageNumber);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      final q = value.trim();
      final searcher = _searcher;
      if (searcher == null) return;
      if (q.isEmpty) {
        searcher.resetTextSearch();
        return;
      }
      searcher.startTextSearch(tajikSearchPattern(q), caseInsensitive: true);
    });
  }

  Future<void> _nextMatch() async {
    final searcher = _searcher;
    if (searcher == null || searcher.matches.isEmpty) return;
    await searcher.goToNextMatch();
  }

  Future<void> _prevMatch() async {
    final searcher = _searcher;
    if (searcher == null || searcher.matches.isEmpty) return;
    await searcher.goToPrevMatch();
  }

  Future<void> _toggleNight() async {
    final next = !_night;
    await ProgressService.instance.setNightMode(next);
    if (mounted) setState(() => _night = next);
  }

  Future<void> _toggleBookmark() async {
    await ProgressService.instance.toggleBookmark(widget.book.id, _page);
    if (mounted) setState(() {});
  }

  Future<void> _showBookmarks() async {
    final pages = ProgressService.instance.bookmarksFor(widget.book.id);
    if (!mounted) return;
    if (pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ҳанӯз хатчӯб нест. Нишони хатчӯбро пахш кунед.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return ListView(
          children: [
            const ListTile(
              title: Text(
                'Хатчӯбҳо',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final page in pages)
              ListTile(
                leading: const Icon(Icons.bookmark_rounded),
                title: Text('Саҳифаи $page'),
                onTap: () => Navigator.pop(ctx, page),
              ),
          ],
        );
      },
    );
    if (picked == null || !_pdfController.isReady) return;
    await _pdfController.goToPage(pageNumber: picked.clamp(1, _pageCount));
  }

  Future<void> _editNote() async {
    final input = TextEditingController(
      text: ProgressService.instance.noteFor(widget.book.id),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ёддошти китоб'),
        content: TextField(
          controller: input,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Масалан: саҳ. 12 — машқи хонагӣ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Бекор'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сабт'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await ProgressService.instance.saveNote(widget.book.id, input.text);
      if (mounted) setState(() {});
    }
    input.dispose();
  }

  Future<void> _jumpDialog() async {
    if (!_pdfController.isReady) return;
    final input = TextEditingController(text: '$_page');
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ба саҳифа гузаред'),
          content: TextField(
            controller: input,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: InputDecoration(hintText: '1 – $_pageCount'),
            onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Бекор'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, int.tryParse(input.text)),
              child: const Text('Гузаштан'),
            ),
          ],
        );
      },
    );
    input.dispose();
    if (result == null || !_pdfController.isReady) return;
    final page = result.clamp(1, _pageCount);
    await _pdfController.goToPage(pageNumber: page);
  }

  @override
  Widget build(BuildContext context) {
    final searcher = _searcher;
    final matches = searcher?.matches.length ?? 0;
    final matchIndex = searcher?.currentIndex ?? 0;
    final searching = _searchController.text.trim().isNotEmpty;

    final paper = _night ? const Color(0xFF1A1A1A) : const Color(0xFFEEE6D6);
    final pdfBg = _night ? const Color(0xFF111111) : const Color(0xFFF3EEE4);
    final bookmarked =
        ProgressService.instance.isBookmarked(widget.book.id, _page);

    return Scaffold(
      backgroundColor: paper,
      body: Column(
        children: [
          const BannerAdSlot(),
          _TopBar(
            title: widget.book.title,
            page: _page,
            pageCount: _pageCount,
            searching: _showSearch,
            bookmarked: bookmarked,
            night: _night,
            onBack: () => Navigator.pop(context),
            onZoomOut: _ready ? _zoomOut : null,
            onZoomIn: _ready ? _zoomIn : null,
            onBookmark: _ready ? _toggleBookmark : null,
            onBookmarks: _showBookmarks,
            onNote: _editNote,
            onNight: _toggleNight,
            onSearch: () {
              setState(() {
                _showSearch = !_showSearch;
                if (_showSearch) {
                  _searchFocus.requestFocus();
                } else {
                  _searchController.clear();
                  _searcher?.resetTextSearch();
                }
              });
            },
            onJump: _ready ? _jumpDialog : null,
          ),
          if (_showSearch)
            _SearchBar(
              controller: _searchController,
              focusNode: _searchFocus,
              matchIndex: matchIndex,
              matchCount: matches,
              onChanged: _onQueryChanged,
              onNext: _nextMatch,
              onPrev: _prevMatch,
            ),
          Expanded(
            child: PdfViewer(
              _pdfRef,
              controller: _pdfController,
              params: PdfViewerParams(
                margin: 2,
                backgroundColor: pdfBg,
                pageDropShadow: const BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
                matchTextColor: const Color(0xAAFFD54F),
                activeMatchTextColor: const Color(0xCCFF8F00),
                onePassRenderingSizeThreshold: 4500,
                getPageRenderingScale: (context, page, controller, estimated) {
                  final dpr = MediaQuery.devicePixelRatioOf(context);
                  var scale = estimated * dpr;
                  if (controller.isReady && controller.currentZoom > 1.15) {
                    scale *= 1.45;
                  }
                  final w = page.width * scale;
                  final h = page.height * scale;
                  if (w > 5500 || h > 5500) {
                    scale = math.min(5500 / page.width, 5500 / page.height);
                  }
                  return scale;
                },
                calculateInitialPageNumber: _initialPage,
                onViewerReady: _onViewerReady,
                onPageChanged: _onPageChanged,
                errorBannerBuilder: (context, error, stackTrace, documentRef) {
                  return ColoredBox(
                    color: const Color(0xFFF3EEE4),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              size: 48,
                              color: AppTheme.tealDark,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Китоб ҳоло кушода нашуд. '
                              'Лутфан аз нав боргирӣ кунед.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () async {
                                await BookCache.instance.deletePdf(widget.book.id);
                                if (context.mounted) Navigator.pop(context);
                              },
                              child: const Text('Аз нав боргирӣ'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                pagePaintCallbacks: [
                  (canvas, rect, page) {
                    _searcher?.pageTextMatchPaintCallback(canvas, rect, page);
                  },
                ],
              ),
            ),
          ),
          if (_ready)
            _PageStrip(
              page: _page.clamp(1, _pageCount),
              pageCount: _pageCount < 1 ? 1 : _pageCount,
              onChanged: (value) {
                if (!_pdfController.isReady) return;
                final page = value.round().clamp(1, _pageCount);
                _pdfController.goToPage(pageNumber: page);
              },
              onZoomOut: _zoomOut,
              onZoomIn: _zoomIn,
            ),
          if (searching && _ready && matches == 0 && !(searcher?.isSearching ?? true))
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'Матн ёфт нашуд — калимаи дигар нависед',
                style: TextStyle(fontSize: 12, color: Colors.brown),
              ),
            ),
          const BannerAdSlot(),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.page,
    required this.pageCount,
    required this.searching,
    required this.bookmarked,
    required this.night,
    required this.onBack,
    required this.onSearch,
    required this.onJump,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onBookmark,
    required this.onBookmarks,
    required this.onNote,
    required this.onNight,
  });

  final String title;
  final int page;
  final int pageCount;
  final bool searching;
  final bool bookmarked;
  final bool night;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback? onJump;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;
  final VoidCallback? onBookmark;
  final VoidCallback onBookmarks;
  final VoidCallback onNote;
  final VoidCallback onNight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.tealDark,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Хатчӯб',
                onPressed: onBookmark,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                icon: Icon(
                  bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: bookmarked ? const Color(0xFFE9C46A) : Colors.white,
                  size: 20,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Бештар',
                color: Colors.white,
                onSelected: (value) {
                  if (value == 'marks') onBookmarks();
                  if (value == 'note') onNote();
                  if (value == 'night') onNight();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'marks',
                    child: Text('Хатчӯбҳо'),
                  ),
                  const PopupMenuItem(
                    value: 'note',
                    child: Text('Ёддошт'),
                  ),
                  PopupMenuItem(
                    value: 'night',
                    child: Text(night ? 'Реҷаи рӯз' : 'Реҷаи шаб'),
                  ),
                ],
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
              ),
              IconButton(
                tooltip: 'Хурд',
                onPressed: onZoomOut,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 20),
              ),
              IconButton(
                tooltip: 'Калон',
                onPressed: onZoomIn,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
              TextButton(
                onPressed: onJump,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '$page / $pageCount',
                  style: const TextStyle(
                    color: Color(0xFFE9C46A),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: onSearch,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  searching ? Icons.search_off_rounded : Icons.search_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.matchIndex,
    required this.matchCount,
    required this.onChanged,
    required this.onNext,
    required this.onPrev,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int matchIndex;
  final int matchCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  @override
  Widget build(BuildContext context) {
    final label = matchCount == 0
        ? '0'
        : '${(matchIndex + 1).clamp(1, matchCount)} / $matchCount';
    return Container(
      color: AppTheme.paper,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Калима нависед…',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.tealDark,
            ),
          ),
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      ),
    );
  }
}

class _PageStrip extends StatelessWidget {
  const _PageStrip({
    required this.page,
    required this.pageCount,
    required this.onChanged,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  final int page;
  final int pageCount;
  final ValueChanged<double> onChanged;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;

  @override
  Widget build(BuildContext context) {
    final max = pageCount < 1 ? 1.0 : pageCount.toDouble();
    final value = page.clamp(1, pageCount < 1 ? 1 : pageCount).toDouble();
    return Material(
      color: AppTheme.paper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Row(
          children: [
            IconButton(
              onPressed: page > 1 ? () => onChanged((page - 1).toDouble()) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  min: 1,
                  max: max,
                  value: value.clamp(1, max),
                  onChanged: onChanged,
                ),
              ),
            ),
            IconButton(
              onPressed: page < pageCount
                  ? () => onChanged((page + 1).toDouble())
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            IconButton(
              tooltip: 'Хурд',
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            IconButton(
              tooltip: 'Калон',
              onPressed: onZoomIn,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

