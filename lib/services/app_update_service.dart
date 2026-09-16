import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_release.dart';
import 'api_service.dart';
import 'progress_service.dart';

class AppUpdateService {
  AppUpdateService._();
  static final instance = AppUpdateService._();

  final _api = ApiService();
  AppRelease? latest;

  Future<AppRelease?> check() async {
    latest = await _api.fetchAppRelease();
    return latest;
  }

  Future<bool> shouldPrompt() async {
    final remote = latest ?? await check();
    if (remote == null || remote.versionCode <= 0) return false;
    final info = await PackageInfo.fromPlatform();
    final localCode = int.tryParse(info.buildNumber) ?? 0;
    if (remote.versionCode <= localCode) return false;
    if (remote.forceUpdate) return true;
    return remote.versionCode > ProgressService.instance.dismissedUpdateCode;
  }
}
