import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/book.dart';
import '../models/school_grade.dart';
import '../services/ads_service.dart';
import '../services/app_update_service.dart';
import '../services/book_cache.dart';
import '../services/book_search.dart';
import '../services/catalog_service.dart';
import '../services/notices_service.dart';
import '../services/progress_service.dart';
import '../services/tajik_text.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_slot.dart';
import '../widgets/book_card.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searchingPages = false;
  List<TextHit> _hits = const [];
  _LibraryFilter _filter = _LibraryFilter.all;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await Future.wait([
      CatalogService.instance.refresh(),
      AdsService.instance.refresh(),
      NoticesService.instance.refresh(),
    ]);
    if (mounted) setState(() {});
    await _maybePromptUpdate();
  }

  Future<void> _maybePromptUpdate() async {
    final updater = AppUpdateService.instance;
    if (!await updater.shouldPrompt()) return;
    if (!mounted) return;
    final remote = updater.latest;
    if (remote == null) return;

    final grades = CatalogService.instance.grades.where((g) => g.number == kGrade);
    final fromClass = grades.isEmpty ? null : grades.first;
    final android = fromClass?.androidUrl ?? remote.androidUrl;
    final ios = fromClass?.iosUrl ?? remote.iosUrl;
    final link = (!kIsWeb && Platform.isIOS) ? ios : android;

    await showDialog<void>(
      context: context,
      barrierDismissible: !remote.forceUpdate,
      builder: (ctx) {
        return PopScope(
          canPop: !remote.forceUpdate,
          child: AlertDialog(
            title: Text(remote.title),
            content: Text(remote.message, style: const TextStyle(height: 1.4)),
            actions: [
              if (!remote.forceUpdate)
                TextButton(
                  onPressed: () {
                    ProgressService.instance.dismissUpdate(remote.versionCode);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Баъдтар'),
                ),
              FilledButton(
                onPressed: () {
                  if (link != null) {
                    final uri = Uri.tryParse(link);
                    if (uri != null) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                  if (!remote.forceUpdate) Navigator.pop(ctx);
                },
                child: const Text('Навсозӣ кунед'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showNotices() async {
    await NoticesService.instance.markAllSeen();
    if (mounted) setState(() {});
    if (!mounted) return;
    final items = NoticesService.instance.items;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none_rounded, size: 40),
                SizedBox(height: 12),
                Text(
                  'Ҳоло огоҳӣ нест',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
          );
        }
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, controller) {
            return ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = items[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    n.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(n.body, style: const TextStyle(height: 1.35)),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    setState(() {
      _query = value;
      if (value.trim().length < 2) {
        _hits = const [];
        _searchingPages = false;
      }
    });
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 160), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    setState(() => _searchingPages = true);
    final hits = await BookSearch.instance.searchInPages(
      q,
      onPartial: (soFar) {
        if (!mounted || _query.trim() != q) return;
        setState(() => _hits = soFar);
      },
    );
    if (!mounted || _query.trim() != q) return;
    setState(() {
      _hits = hits;
      _searchingPages = false;
    });
  }

  Future<void> _open(
    BookItem book, {
    int? page,
    String? query,
  }) async {
    AdsService.instance.setBookContext(book.title, subtitle: book.subtitle);
    await AdsService.instance.maybeShowInterstitial();
    if (!mounted) return;
    BookItem ready = book;
    final alreadyDownloading = BookCache.instance.isDownloading(book.id);
    final needsDownload =
        alreadyDownloading || !await BookCache.instance.hasValidPdf(book.id);
    if (needsDownload) {
      if (!alreadyDownloading) {
        final bytes = await BookCache.instance.probePdfBytes(book);
        if (!mounted) return;
        final sizeText = bytes == null
            ? 'ҳаҷм пас аз оғоз маълум мешавад'
            : BookCache.formatBytes(bytes);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Боргирии китоб'),
            content: Text(
              'Китоби «${book.title}» дар барнома нест. '
              'Аввал файлро аз интернет боргирӣ кунед ($sizeText), '
              'баъд бе интернет хондан мумкин аст.\n\n'
              'Манбаъ: $kSourceUrl',
              style: const TextStyle(height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Не'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Боргирӣ'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      var hidden = false;
      var dialogOpen = true;

      void closeDialog() {
        if (!dialogOpen) return;
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(20, 8, 4, 0),
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Боргирӣ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Дар пасзамина',
                  onPressed: () {
                    hidden = true;
                    closeDialog();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            content: ValueListenableBuilder<int>(
              valueListenable: BookCache.instance.progressOf(book.id),
              builder: (context, value, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Китоби «${book.title}» боргирӣ мешавад',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: value == 0 ? null : value / 100,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value == 0 ? 'Оғоз…' : '$value%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.tealDark,
                      ),
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  BookCache.instance.cancel(book.id);
                  closeDialog();
                },
                child: const Text('Қатъ'),
              ),
            ],
          );
        },
      );
      try {
        ready = await BookCache.instance.ensurePdf(book);
        ready = await BookCache.instance.ensureCover(ready);
      } catch (e) {
        if (!mounted) return;
        closeDialog();
        if (e is DioException && CancelToken.isCancel(e)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Китоби «${book.title}» боргирӣ нашуд. Интернетро санҷед.',
            ),
          ),
        );
        return;
      }
      CatalogService.instance.replaceBook(ready);
      if (!mounted) return;
      if (hidden) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Китоби «${book.title}» боргирӣ шуд'),
            action: SnackBarAction(
              label: 'Кушодан',
              onPressed: () => _open(ready),
            ),
          ),
        );
        return;
      }
      closeDialog();
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ReaderScreen(
          book: ready,
          initialPage: page,
          initialQuery: query,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (mounted) setState(() {});
  }

  bool _gradeHasStoreLink(SchoolGrade grade) {
    return (!kIsWeb && Platform.isIOS) ? grade.hasIosLink : grade.hasAndroidLink;
  }

  void _openGrade(SchoolGrade grade) {
    Navigator.pop(context);
    if (grade.number == kGrade) return;
    final link = (!kIsWeb && Platform.isIOS) ? grade.iosUrl : grade.androidUrl;
    if (link == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${grade.name}: линк ҳанӯз дар админка гузошта нашудааст. Пас аз нашр пур кунед.',
          ),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showNotes() {
    Navigator.pop(context);
    final catalog = CatalogService.instance;
    final items = [
      for (final book in catalog.books)
        if (ProgressService.instance.noteFor(book.id).isNotEmpty)
          (book: book, note: ProgressService.instance.noteFor(book.id)),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Text(
              'Ҳанӯз ёддошт нест. Китобро кушоед ва аз меню «Ёддошт»-ро интихоб кунед.',
              style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final item = items[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.book.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(item.note, maxLines: 3),
              onTap: () {
                Navigator.pop(context);
                _open(item.book);
              },
            );
          },
        );
      },
    );
  }

  void _showAbout() {
    Navigator.pop(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFC9BBA8)),
        ),
        title: const Text(
          'Дар бораи барнома',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Text(
            kAboutText,
            style: TextStyle(
              height: 1.55,
              fontSize: 14.5,
              color: AppTheme.ink,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              launchUrl(
                Uri.parse(kSourceUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Манбаи китобҳо'),
          ),
          TextButton(
            onPressed: () {
              launchUrl(
                Uri.parse(kPrivacyUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Сиёсати махфият'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Хуб'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    final catalog = CatalogService.instance;
    final lastId = progress.lastBookId;
    BookItem? lastBook;
    if (lastId != null) {
      final found = catalog.books.where((b) => b.id == lastId);
      if (found.isNotEmpty) lastBook = found.first;
    }
    final books = BookSearch.instance.booksByTitle(_query);
    final q = _query.trim();
    final searching = q.length >= 2;
    var visible = books;
    if (!searching) {
      switch (_filter) {
        case _LibraryFilter.all:
          break;
        case _LibraryFilter.offline:
          visible = books.where((b) => b.hasLocalFile).toList();
        case _LibraryFilter.favorites:
          visible = books.where((b) => progress.isFavorite(b.id)).toList();
        case _LibraryFilter.continueReading:
          visible = books.where((b) => progress.pageFor(b.id) > 1).toList();
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(catalog.className),
        actions: [
          IconButton(
            tooltip: 'Огоҳиҳо',
            onPressed: _showNotices,
            icon: Badge(
              isLabelVisible: NoticesService.instance.unreadCount > 0,
              smallSize: 8,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Меню',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text(
                  'Дар бораи барнома',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: _showAbout,
              ),
              ListTile(
                leading: const Icon(Icons.public_rounded),
                title: const Text(
                  'Манбаи китобҳо',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('maorif.tj'),
                onTap: () {
                  Navigator.pop(context);
                  launchUrl(
                    Uri.parse(kSourceUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text(
                  'Ёддоштҳои ман',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: _showNotes,
              ),
              const Divider(),
              for (final grade in catalog.grades)
                ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: grade.number == kGrade
                        ? AppTheme.teal
                        : Colors.brown.shade100,
                    child: Text(
                      '${grade.number}',
                      style: TextStyle(
                        color: grade.number == kGrade
                            ? Colors.white
                            : AppTheme.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  title: Text(
                    grade.name,
                    style: TextStyle(
                      fontWeight: grade.number == kGrade
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  subtitle: grade.number == kGrade
                      ? null
                      : Text(
                          _gradeHasStoreLink(grade)
                              ? 'Зеркашӣ'
                              : 'Ба наздикӣ — линк аз админка',
                        ),
                  selected: grade.number == kGrade,
                  hoverColor: AppTheme.teal.withValues(alpha: 0.08),
                  onTap: () => _openGrade(grade),
                ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          const BannerAdSlot(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _search,
                      onChanged: _onQuery,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Калима нависед — дар ҳама китобҳо…',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: Colors.brown.shade400,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 26),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFC9BBA8),
                            width: 1.3,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppTheme.teal,
                            width: 1.7,
                          ),
                        ),
                        suffixIcon: q.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _search.clear();
                                  _onQuery('');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                ),
                if (!searching)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => launchUrl(
                              Uri.parse(kSourceUrl),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: const Text(
                              'Манбаъ: maorif.tj/libraries — барномаи расмии вазорат нест',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppTheme.tealDark,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final item in _LibraryFilter.values)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(item.label),
                                      selected: _filter == item,
                                      onSelected: (_) =>
                                          setState(() => _filter = item),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (lastBook != null && !searching && catalog.books.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ContinueCard(
                      book: lastBook,
                      page: progress.pageFor(lastBook.id),
                      onOpen: () {
                        final book = lastBook;
                        if (book != null) _open(book);
                      },
                    ),
                  ),
                if (searching)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _searchingPages
                                  ? 'Дар ҳама китобҳо меҷӯем…'
                                  : (_hits.isEmpty
                                      ? 'Ин калима дар матн ёфт нашуд'
                                      : 'Ёфт шуд: ${_hits.length} ҷо'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.tealDark,
                              ),
                            ),
                          ),
                          if (_searchingPages)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (searching && _hits.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final hit = _hits[i];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                          child: Material(
                          color: Colors.white,
                          elevation: 1,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Color(0xFFC9BBA8),
                              width: 1.2,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            splashColor: AppTheme.teal.withValues(alpha: 0.16),
                            highlightColor: AppTheme.teal.withValues(alpha: 0.08),
                            onTap: () => _open(
                              hit.book,
                              page: hit.page,
                              query: q,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 40,
                                      height: 52,
                                      child: BookCover(book: hit.book),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${hit.book.title}  ·  саҳ. ${hit.page}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        _HighlightText(
                                          text: hit.snippet,
                                          query: q,
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Кушодан →',
                                          style: TextStyle(
                                            color: AppTheme.teal,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        );
                      },
                      childCount: _hits.length,
                    ),
                  ),
                if (catalog.loading && catalog.books.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (catalog.books.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 48,
                            color: Colors.brown.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            catalog.error ??
                                'Дар админка барои ин синф ҳанӯз китоб нест.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _reload,
                            child: const Text('Аз нав кӯшиш'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!searching && visible.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Дар ин рӯйхат китоб нест. Филтри дигарро интихоб кунед.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final book = visible[i];
                        return BookCard(
                          book: book,
                          page: progress.pageFor(book.id),
                          onOpen: () => _open(book),
                          onFavorite: () async {
                            await progress.toggleFavorite(book.id);
                            if (mounted) setState(() {});
                          },
                        );
                      },
                      childCount: visible.length,
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
          const BannerAdSlot(),
        ],
      ),
    );
  }
}

enum _LibraryFilter {
  all,
  offline,
  favorites,
  continueReading;

  String get label => switch (this) {
        all => 'Ҳама',
        offline => 'Офлайн',
        favorites => 'Дӯстдошта',
        continueReading => 'Идома',
      };
}

class _HighlightText extends StatelessWidget {
  const _HighlightText({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
    final folded = foldTajik(text);
    final needle = foldTajik(q);
    if (needle.isEmpty) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final i = folded.indexOf(needle, start);
      if (i < 0) {
        spans.add(TextSpan(text: text.substring(start.clamp(0, text.length))));
        break;
      }
      if (i > start) {
        spans.add(TextSpan(
          text: text.substring(start.clamp(0, text.length), i.clamp(0, text.length)),
        ));
      }
      final end = (i + needle.length).clamp(0, text.length);
      spans.add(
        TextSpan(
          text: text.substring(i.clamp(0, text.length), end),
          style: const TextStyle(
            backgroundColor: Color(0xFFFFE08A),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      start = end;
    }
    return Text.rich(
      TextSpan(style: const TextStyle(fontSize: 13, height: 1.3), children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.book,
    required this.page,
    required this.onOpen,
  });

  final BookItem book;
  final int page;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Material(
        color: AppTheme.tealDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE9C46A), width: 1.1),
        ),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 64,
                  child: BookCover(book: book),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Шумо саҳифаи $page-ро аз китоби «${book.title}» хондаед',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 34,
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
