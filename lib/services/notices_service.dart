import '../config.dart';
import '../models/app_release.dart';
import 'api_service.dart';
import 'progress_service.dart';

class NoticesService {
  NoticesService._();
  static final instance = NoticesService._();

  final _api = ApiService();
  List<AppNotice> items = const [];

  int get unreadCount {
    final seen = ProgressService.instance.lastSeenNoticeId;
    return items.where((n) => n.id > seen).length;
  }

  Future<void> refresh() async {
    items = await _api.fetchNotices(kGrade);
  }

  Future<void> markAllSeen() async {
    if (items.isEmpty) return;
    final maxId = items.map((n) => n.id).reduce((a, b) => a > b ? a : b);
    await ProgressService.instance.markNoticesSeen(maxId);
  }
}
